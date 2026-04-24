-- Replacement exchange orchestration (additive + backward compatible).

alter table public.orders
  add column if not exists order_kind text not null default 'normal',
  add column if not exists original_order_id uuid references public.orders(id) on delete set null,
  add column if not exists replacement_case_id uuid;

alter table public.orders
  drop constraint if exists orders_order_kind_check;

alter table public.orders
  add constraint orders_order_kind_check
  check (order_kind in ('normal', 'replacement'));

create index if not exists idx_orders_order_kind on public.orders(order_kind);
create index if not exists idx_orders_original_order_id on public.orders(original_order_id)
  where original_order_id is not null;

create table if not exists public.replacement_cases (
  id uuid primary key default gen_random_uuid(),
  return_id uuid unique references public.returns(id) on delete set null,
  original_order_id uuid not null references public.orders(id) on delete cascade,
  original_order_item_id uuid not null references public.order_items(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  replacement_order_id uuid references public.orders(id) on delete set null,
  reason text,
  status text not null default 'requested'
    check (status in (
      'requested',
      'approved',
      'replacement_order_created',
      'replacement_dispatched',
      'replacement_delivered',
      'pickup_scheduled',
      'pickup_in_progress',
      'pickup_completed',
      'completed',
      'rejected',
      'cancelled',
      'failed'
    )),
  failure_reason text,
  attempt_count int not null default 0,
  approved_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_replacement_cases_updated_at on public.replacement_cases;
create trigger trg_replacement_cases_updated_at
before update on public.replacement_cases
for each row execute function public.set_updated_at();

create unique index if not exists replacement_cases_one_active_per_item
  on public.replacement_cases(original_order_item_id)
  where status not in ('completed', 'rejected', 'cancelled', 'failed');

create table if not exists public.replacement_pickups (
  id uuid primary key default gen_random_uuid(),
  replacement_case_id uuid not null references public.replacement_cases(id) on delete cascade,
  provider text not null default 'manual',
  awb_code text,
  tracking_url text,
  scheduled_at timestamptz,
  status text not null default 'pickup_scheduled'
    check (status in (
      'pickup_scheduled',
      'pickup_in_progress',
      'pickup_completed',
      'pickup_failed',
      'cancelled'
    )),
  attempt_no int not null default 1,
  failure_code text
    check (failure_code is null or failure_code in (
      'user_unavailable',
      'address_issue',
      'item_not_ready',
      'courier_issue',
      'quality_dispute',
      'other'
    )),
  failure_reason text,
  proof_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_replacement_pickups_updated_at on public.replacement_pickups;
create trigger trg_replacement_pickups_updated_at
before update on public.replacement_pickups
for each row execute function public.set_updated_at();

create index if not exists idx_replacement_pickups_case on public.replacement_pickups(replacement_case_id, created_at desc);
create index if not exists idx_replacement_pickups_status on public.replacement_pickups(status, scheduled_at);

create table if not exists public.replacement_case_events (
  id uuid primary key default gen_random_uuid(),
  replacement_case_id uuid not null references public.replacement_cases(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  prev_status text,
  next_status text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_replacement_case_events_case on public.replacement_case_events(replacement_case_id, created_at desc);

create or replace function public.replacement_cases_log_status_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.replacement_case_events(
      replacement_case_id,
      actor_user_id,
      event_type,
      next_status,
      details
    )
    values(
      new.id,
      auth.uid(),
      'replacement_case_created',
      new.status,
      jsonb_build_object('return_id', new.return_id, 'replacement_order_id', new.replacement_order_id)
    );
    return new;
  end if;

  if old.status is distinct from new.status then
    insert into public.replacement_case_events(
      replacement_case_id,
      actor_user_id,
      event_type,
      prev_status,
      next_status,
      details
    )
    values(
      new.id,
      auth.uid(),
      'replacement_case_status_changed',
      old.status,
      new.status,
      jsonb_build_object('failure_reason', new.failure_reason, 'attempt_count', new.attempt_count)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_replacement_cases_log_status_event on public.replacement_cases;
create trigger trg_replacement_cases_log_status_event
after insert or update of status on public.replacement_cases
for each row execute function public.replacement_cases_log_status_event();

create or replace function public.replacement_pickups_sync_case_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
begin
  if tg_op = 'INSERT' then
    if new.status = 'pickup_scheduled' then
      update public.replacement_cases
      set status = case
          when status in ('replacement_delivered', 'pickup_scheduled', 'pickup_in_progress')
            then status
          else 'pickup_scheduled'
        end
      where id = new.replacement_case_id;
    end if;
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'pickup_in_progress' then
    update public.replacement_cases
    set status = 'pickup_in_progress'
    where id = new.replacement_case_id
      and status not in ('completed', 'cancelled', 'rejected');
  elsif new.status = 'pickup_completed' then
    update public.replacement_cases
    set status = 'pickup_completed'
    where id = new.replacement_case_id
      and status not in ('completed', 'cancelled', 'rejected');
  elsif new.status = 'pickup_failed' then
    update public.replacement_cases
    set status = 'failed',
        failure_reason = coalesce(new.failure_reason, new.failure_code),
        attempt_count = greatest(attempt_count, new.attempt_no)
    where id = new.replacement_case_id
      and status not in ('completed', 'cancelled', 'rejected');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_replacement_pickups_sync_case_status on public.replacement_pickups;
create trigger trg_replacement_pickups_sync_case_status
after insert or update of status, failure_code, failure_reason, attempt_no
on public.replacement_pickups
for each row execute function public.replacement_pickups_sync_case_status();

create or replace function public.replacement_forward_status_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    update public.replacement_cases
    set
    forward_status = case lower(trim(new.status))
      when 'processing' then 'created'
      when 'packed' then 'created'
      when 'shipped' then 'in_transit'
      when 'out_for_delivery' then 'out_for_delivery'
      when 'delivered' then 'delivered'
      when 'cancelled' then 'cancelled'
      else forward_status
    end,
    status = case lower(trim(new.status))
      when 'processing' then 'replacement_order_created'
      when 'packed' then 'replacement_order_created'
      when 'shipped' then 'replacement_dispatched'
      when 'out_for_delivery' then 'replacement_dispatched'
      when 'delivered' then 'replacement_delivered'
      else status
    end,
    completed_at = completed_at
    where replacement_order_id = new.id
      and status not in ('completed', 'cancelled', 'rejected');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_replacement_forward_status_sync on public.orders;
create trigger trg_replacement_forward_status_sync
after update of status on public.orders
for each row execute function public.replacement_forward_status_sync();

alter table public.orders
  add constraint orders_replacement_case_id_fkey
  foreign key (replacement_case_id)
  references public.replacement_cases(id)
  on delete set null;

create or replace function public.admin_approve_replacement_return(
  p_return_id uuid,
  p_schedule_pickup_at timestamptz default null
)
returns table(
  replacement_case_id uuid,
  replacement_order_id uuid,
  pickup_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_return record;
  v_parent public.orders%rowtype;
  v_item record;
  v_case public.replacement_cases%rowtype;
  v_new_replacement_order_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_active_admin(v_uid) then
    raise exception 'not_authorized';
  end if;

  select *
  into v_return
  from public.returns r
  where r.id = p_return_id
  for update;

  if not found then
    raise exception 'return_not_found';
  end if;
  if lower(trim(coalesce(v_return.return_type, ''))) <> 'replacement' then
    raise exception 'not_replacement_return';
  end if;
  if lower(trim(coalesce(v_return.return_status, ''))) not in ('requested', 'approved') then
    raise exception 'invalid_return_state_for_approval';
  end if;

  select *
  into v_parent
  from public.orders
  where id = v_return.order_id
  for update;
  if not found then
    raise exception 'parent_order_not_found';
  end if;

  select *
  into v_item
  from public.order_items oi
  where oi.id = v_return.order_item_id
  for update;
  if not found then
    raise exception 'order_item_not_found';
  end if;

  insert into public.replacement_cases(
    return_id,
    original_order_id,
    original_order_item_id,
    customer_id,
    reason,
    status,
    approved_at
  )
  values(
    v_return.id,
    v_return.order_id,
    v_return.order_item_id,
    v_return.user_id,
    v_return.return_reason,
    'approved',
    now()
  )
  on conflict (return_id) do update
  set status = excluded.status,
      approved_at = coalesce(public.replacement_cases.approved_at, excluded.approved_at),
      updated_at = now()
  returning * into v_case;

  if v_return.replacement_order_id is null then
    insert into public.orders (
      user_id,
      status,
      currency,
      shipping_full_name,
      shipping_phone,
      shipping_address_line,
      shipping_city,
      shipping_postal_code,
      shipping_state,
      delivery_fee,
      customer_email,
      payment_method,
      payment_status,
      razorpay_payment_id,
      razorpay_order_id,
      source_return_id,
      order_kind,
      original_order_id,
      replacement_case_id
    ) values (
      v_parent.user_id,
      'pending_payment',
      v_parent.currency,
      v_parent.shipping_full_name,
      v_parent.shipping_phone,
      v_parent.shipping_address_line,
      v_parent.shipping_city,
      v_parent.shipping_postal_code,
      v_parent.shipping_state,
      0,
      v_parent.customer_email,
      'cod',
      'paid',
      null,
      null,
      v_return.id,
      'replacement',
      v_parent.id,
      v_case.id
    )
    returning id into v_new_replacement_order_id;

    insert into public.order_status_history (
      order_id,
      status,
      updated_by,
      notes,
      created_at
    )
    values (
      v_new_replacement_order_id,
      'pending_payment',
      v_uid,
      'Replacement order: deliver new item and collect old item.',
      now()
    );

    insert into public.order_items (
      order_id,
      product_id,
      title,
      image_urls,
      unit_price,
      currency,
      quantity
    ) values (
      v_new_replacement_order_id,
      v_item.product_id,
      v_item.title,
      coalesce(v_item.image_urls, '{}'::text[]),
      v_item.unit_price,
      v_item.currency,
      v_item.quantity
    );

    update public.products pr
    set inventory_count = pr.inventory_count - v_item.quantity
    where pr.id = v_item.product_id
      and v_item.quantity > 0
      and pr.inventory_count >= v_item.quantity;
    if not found then
      raise exception 'insufficient_inventory_for_replacement';
    end if;

    update public.returns
    set replacement_order_id = v_new_replacement_order_id
    where id = v_return.id;
    replacement_order_id := v_new_replacement_order_id;
  else
    replacement_order_id := v_return.replacement_order_id;
  end if;

  update public.replacement_cases
  set replacement_order_id = coalesce(v_new_replacement_order_id, v_return.replacement_order_id),
      status = 'replacement_order_created',
      updated_at = now()
  where id = v_case.id;

  update public.returns
  set return_status = 'approved',
      updated_at = now()
  where id = v_return.id
    and return_status <> 'approved';

  insert into public.replacement_pickups(
    replacement_case_id,
    provider,
    status,
    scheduled_at
  ) values (
    v_case.id,
    'manual',
    'pickup_scheduled',
    coalesce(p_schedule_pickup_at, now() + interval '1 day')
  )
  returning id into pickup_id;

  replacement_case_id := v_case.id;
  return next;
end;
$$;

revoke all on function public.admin_approve_replacement_return(uuid, timestamptz) from public;
grant execute on function public.admin_approve_replacement_return(uuid, timestamptz) to authenticated;

create or replace function public.admin_upsert_replacement_pickup(
  p_replacement_case_id uuid,
  p_status text,
  p_scheduled_at timestamptz default null,
  p_failure_code text default null,
  p_failure_reason text default null,
  p_tracking_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pickup_id uuid;
  v_attempt int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_active_admin(v_uid) then
    raise exception 'not_authorized';
  end if;
  if p_status not in ('pickup_scheduled', 'pickup_in_progress', 'pickup_completed', 'pickup_failed', 'cancelled') then
    raise exception 'invalid_pickup_status';
  end if;

  select coalesce(max(attempt_no), 0)
  into v_attempt
  from public.replacement_pickups
  where replacement_case_id = p_replacement_case_id;

  if p_status = 'pickup_failed' then
    v_attempt := greatest(v_attempt, 1);
  elsif p_status = 'pickup_scheduled' then
    v_attempt := v_attempt + 1;
  else
    v_attempt := greatest(v_attempt, 1);
  end if;

  insert into public.replacement_pickups(
    replacement_case_id,
    provider,
    status,
    scheduled_at,
    attempt_no,
    failure_code,
    failure_reason,
    tracking_url
  ) values (
    p_replacement_case_id,
    'manual',
    p_status,
    p_scheduled_at,
    v_attempt,
    p_failure_code,
    nullif(trim(coalesce(p_failure_reason, '')), ''),
    nullif(trim(coalesce(p_tracking_url, '')), '')
  )
  returning id into v_pickup_id;

  return v_pickup_id;
end;
$$;

revoke all on function public.admin_upsert_replacement_pickup(uuid, text, timestamptz, text, text, text) from public;
grant execute on function public.admin_upsert_replacement_pickup(uuid, text, timestamptz, text, text, text) to authenticated;

create or replace function public.notify_replacement_case_status_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
  v_order_id uuid;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'replacement_order_created' then
    v_title := 'Replacement order created';
    v_body := 'Your replacement order is created and will be dispatched soon.';
  elsif new.status = 'replacement_dispatched' then
    v_title := 'Replacement dispatched';
    v_body := 'Your replacement item has been dispatched.';
  elsif new.status = 'replacement_delivered' then
    v_title := 'Replacement delivered';
    v_body := 'Your replacement item has been delivered. Pickup will be completed shortly.';
  elsif new.status = 'pickup_scheduled' then
    v_title := 'Pickup scheduled';
    v_body := 'Pickup for the original item is scheduled.';
  elsif new.status = 'pickup_in_progress' then
    v_title := 'Pickup in progress';
    v_body := 'Courier is attempting pickup for your original item.';
  elsif new.status = 'pickup_completed' then
    v_title := 'Pickup completed';
    v_body := 'Original item pickup is completed.';
  elsif new.status = 'completed' then
    v_title := 'Replacement completed';
    v_body := 'Replacement and pickup are both completed.';
  elsif new.status = 'failed' then
    v_title := 'Replacement update required';
    v_body := coalesce(nullif(trim(new.failure_reason), ''), 'Pickup attempt failed. We will retry shortly.');
  else
    return new;
  end if;

  v_order_id := coalesce(new.original_order_id, (
    select order_id from public.returns where id = new.return_id
  ));

  insert into public.user_notifications(user_id, kind, title, body, order_id)
  values (new.customer_id, 'return_refund', v_title, v_body, v_order_id);
  return new;
end;
$$;

drop trigger if exists trg_notify_replacement_case_status_update on public.replacement_cases;
create trigger trg_notify_replacement_case_status_update
after update of status on public.replacement_cases
for each row execute function public.notify_replacement_case_status_update();

create or replace view public.v_replacement_cases_stuck as
select
  rc.id as replacement_case_id,
  rc.original_order_id,
  rc.replacement_order_id,
  rc.status,
  rc.attempt_count,
  rc.failure_reason,
  rc.updated_at,
  rp.status as latest_pickup_status,
  rp.scheduled_at as latest_pickup_scheduled_at
from public.replacement_cases rc
left join lateral (
  select p.status, p.scheduled_at
  from public.replacement_pickups p
  where p.replacement_case_id = rc.id
  order by p.created_at desc
  limit 1
) rp on true
where rc.status in (
  'replacement_order_created',
  'replacement_dispatched',
  'pickup_scheduled',
  'pickup_in_progress',
  'pickup_completed',
  'failed'
)
and rc.updated_at < now() - interval '48 hours';

grant select on public.v_replacement_cases_stuck to authenticated;

alter table public.replacement_cases enable row level security;
alter table public.replacement_pickups enable row level security;
alter table public.replacement_case_events enable row level security;

drop policy if exists replacement_cases_admin_all on public.replacement_cases;
create policy replacement_cases_admin_all
on public.replacement_cases
for all
to authenticated
using (public.is_active_admin(auth.uid()) or customer_id = auth.uid())
with check (public.is_active_admin(auth.uid()));

drop policy if exists replacement_pickups_admin_select on public.replacement_pickups;
create policy replacement_pickups_admin_select
on public.replacement_pickups
for select
to authenticated
using (
  public.is_active_admin(auth.uid()) or exists (
    select 1
    from public.replacement_cases rc
    where rc.id = replacement_pickups.replacement_case_id
      and rc.customer_id = auth.uid()
  )
);

drop policy if exists replacement_pickups_admin_write on public.replacement_pickups;
create policy replacement_pickups_admin_write
on public.replacement_pickups
for all
to authenticated
using (public.is_active_admin(auth.uid()))
with check (public.is_active_admin(auth.uid()));

drop policy if exists replacement_case_events_admin_select on public.replacement_case_events;
create policy replacement_case_events_admin_select
on public.replacement_case_events
for select
to authenticated
using (
  public.is_active_admin(auth.uid()) or exists (
    select 1
    from public.replacement_cases rc
    where rc.id = replacement_case_events.replacement_case_id
      and rc.customer_id = auth.uid()
  )
);
