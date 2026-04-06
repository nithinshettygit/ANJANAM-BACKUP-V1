-- Standardized return lifecycle for app/admin consistency.

-- Prevent old transition guard from blocking legacy status normalization.
drop trigger if exists trg_returns_before_write_status on public.returns;

-- 1) Add/verify requested return fields on order_items.
alter table public.order_items
  add column if not exists return_requested boolean not null default false,
  add column if not exists return_status text not null default 'none',
  add column if not exists return_reason text,
  add column if not exists return_requested_at timestamptz,
  add column if not exists return_processed_at timestamptz;

alter table public.order_items
  drop constraint if exists order_items_return_status_check;

alter table public.order_items
  add constraint order_items_return_status_check
  check (
    return_status in (
      'none',
      'requested',
      'approved',
      'rejected',
      'picked_up',
      'returned',
      'refund_completed'
    )
  );

-- 2) Standardize returns.return_status values.
alter table public.returns
  drop constraint if exists returns_return_status_check;

update public.returns
set return_status = case lower(trim(return_status))
  when 'return_requested' then 'requested'
  when 'return_approved' then 'approved'
  when 'pickup_scheduled' then 'approved'
  when 'item_picked_up' then 'picked_up'
  when 'item_received_warehouse' then 'returned'
  when 'inspection_passed' then 'returned'
  when 'replacement_in_progress' then 'returned'
  when 'inspection_failed' then 'rejected'
  when 'return_rejected' then 'rejected'
  else 'requested'
end;

alter table public.returns
  add constraint returns_return_status_check
  check (
    return_status in (
      'requested',
      'approved',
      'rejected',
      'picked_up',
      'returned',
      'refund_completed'
    )
  );

drop index if exists public.returns_one_active_per_order_item;
create unique index if not exists returns_one_active_per_order_item
  on public.returns (order_item_id)
  where return_status not in ('rejected', 'refund_completed');

-- 3) Strict transition guard.
create or replace function public.returns_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select case lower(trim(coalesce(p_old, '')))
    when 'requested' then lower(trim(coalesce(p_new, ''))) in ('approved', 'rejected')
    when 'approved' then lower(trim(coalesce(p_new, ''))) in ('picked_up')
    when 'picked_up' then lower(trim(coalesce(p_new, ''))) in ('returned')
    when 'returned' then lower(trim(coalesce(p_new, ''))) in ('refund_completed')
    when 'rejected' then false
    when 'refund_completed' then false
    else false
  end;
$$;

create or replace function public.returns_before_write_status()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_old text;
  v_new text;
begin
  if tg_op = 'INSERT' then
    new.return_status := lower(trim(coalesce(new.return_status, 'requested')));
    return new;
  end if;

  if new.return_status is not null then
    new.return_status := lower(trim(new.return_status));
  end if;

  if old.return_status is distinct from new.return_status then
    v_old := lower(trim(coalesce(old.return_status, '')));
    v_new := lower(trim(coalesce(new.return_status, '')));
    if not public.returns_valid_status_transition(v_old, v_new) then
      raise exception 'invalid_return_status_transition: % -> %', old.return_status, new.return_status;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_returns_before_write_status on public.returns;
create trigger trg_returns_before_write_status
before insert or update of return_status
on public.returns
for each row
execute function public.returns_before_write_status();

-- 4) Keep order_items fields in sync with returns.
create or replace function public.sync_order_item_return_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_item_id uuid;
  v_status text;
  v_reason text;
  v_requested_at timestamptz;
  v_processed_at timestamptz;
begin
  v_order_item_id := case when tg_op = 'INSERT' then new.order_item_id else coalesce(new.order_item_id, old.order_item_id) end;

  select
    r.return_status,
    r.return_reason,
    case
      when r.return_status in ('rejected', 'refund_completed', 'returned') then r.updated_at
      else null
    end
  into v_status, v_reason, v_processed_at
  from public.returns r
  where r.order_item_id = v_order_item_id
  order by r.created_at desc
  limit 1;

  select min(r.created_at)
  into v_requested_at
  from public.returns r
  where r.order_item_id = v_order_item_id;

  update public.order_items oi
  set
    return_requested = (v_status is not null and v_status <> 'none'),
    return_status = coalesce(v_status, 'none'),
    return_reason = v_reason,
    return_requested_at = v_requested_at,
    return_processed_at = v_processed_at
  where oi.id = v_order_item_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_returns_sync_order_item_return_state on public.returns;
create trigger trg_returns_sync_order_item_return_state
after insert or update of return_status, return_reason, created_at, updated_at
on public.returns
for each row
execute function public.sync_order_item_return_state();

-- Backfill order_items from existing returns after migration.
with latest as (
  select distinct on (r.order_item_id)
    r.order_item_id,
    r.return_status,
    r.return_reason,
    r.created_at,
    case
      when r.return_status in ('rejected', 'refund_completed', 'returned') then r.updated_at
      else null
    end as processed_at
  from public.returns r
  order by r.order_item_id, r.created_at desc
)
update public.order_items oi
set
  return_requested = true,
  return_status = l.return_status,
  return_reason = l.return_reason,
  return_requested_at = l.created_at,
  return_processed_at = l.processed_at
from latest l
where oi.id = l.order_item_id;

-- 5) Customer return creation: strict defensive checks + standardized status.
create or replace function public.create_customer_return(
  p_order_item_id uuid,
  p_return_reason text,
  p_return_note text,
  p_return_images text[],
  p_return_type text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_oid uuid;
  v_pid uuid;
  v_order_user uuid;
  v_order_status text;
  v_delivered_at timestamptz;
  v_return_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_return_reason is null or p_return_reason not in (
    'damaged_item', 'wrong_product', 'size_issue', 'not_satisfied'
  ) then
    raise exception 'invalid_return_reason';
  end if;

  if coalesce(cardinality(p_return_images), 0) < 1 then
    raise exception 'return_images_required';
  end if;

  select oi.order_id, oi.product_id, o.user_id, lower(trim(o.status)), o.delivered_at
  into v_oid, v_pid, v_order_user, v_order_status, v_delivered_at
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where oi.id = p_order_item_id;

  if v_oid is null then
    raise exception 'order_item_not_found';
  end if;
  if v_order_user <> v_uid then
    raise exception 'not_authorized';
  end if;
  if v_order_status <> 'delivered' then
    raise exception 'order_not_delivered';
  end if;
  if v_order_status = 'cancelled' then
    raise exception 'cancelled_order_not_returnable';
  end if;
  if v_delivered_at is null then
    raise exception 'return_deadline_missing';
  end if;
  if v_delivered_at < (now() - interval '7 days') then
    raise exception 'return_window_expired';
  end if;
  if exists (
    select 1 from public.returns r
    where r.order_item_id = p_order_item_id
      and r.return_status not in ('rejected', 'refund_completed')
  ) then
    raise exception 'return_already_exists';
  end if;
  if exists (
    select 1 from public.refunds rf
    join public.returns rr on rr.id = rf.return_id
    where rr.order_item_id = p_order_item_id
      and rf.refund_status = 'refund_completed'
  ) then
    raise exception 'already_refunded';
  end if;

  insert into public.returns (
    order_id, user_id, product_id, order_item_id, return_reason,
    return_note, return_images, return_type, return_status
  ) values (
    v_oid, v_uid, v_pid, p_order_item_id, p_return_reason,
    nullif(trim(p_return_note), ''), p_return_images, coalesce(nullif(trim(p_return_type), ''), 'return'), 'requested'
  )
  returning id into v_return_id;

  return v_return_id;
end;
$$;

grant execute on function public.create_customer_return(uuid, text, text, text[], text) to authenticated;

-- 6) Refund completion updates return status.
create or replace function public.returns_after_refund_status_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.refund_status is distinct from new.refund_status
     and new.refund_status = 'refund_completed' then
    update public.returns
    set return_status = 'refund_completed',
        updated_at = now()
    where id = new.return_id
      and return_status = 'returned';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_refunds_sync_return_status on public.refunds;
create trigger trg_refunds_sync_return_status
after update of refund_status on public.refunds
for each row
execute function public.returns_after_refund_status_sync();

-- 7) Updated return notifications.
create or replace function public.notify_return_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_notifications (user_id, kind, title, body, order_id)
  values (
    new.user_id,
    'return_refund',
    'Replacement request submitted',
    'We received your replacement request. Our team will review it shortly.',
    new.order_id
  );
  return new;
end;
$$;

drop trigger if exists trg_returns_notify_insert on public.returns;
create trigger trg_returns_notify_insert
after insert on public.returns
for each row execute function public.notify_return_insert();

create or replace function public.notify_return_status_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if tg_op <> 'UPDATE' or old.return_status is not distinct from new.return_status then
    return new;
  end if;

  if new.return_status = 'approved' then
    v_title := 'Replacement approved';
    v_body := 'Your replacement request was approved.';
  elsif new.return_status = 'rejected' then
    v_title := 'Replacement rejected';
    v_body := coalesce(
      nullif(trim(new.rejection_reason), ''),
      'Your replacement request was not approved.'
    );
  elsif new.return_status = 'picked_up' then
    v_title := 'Replacement pickup completed';
    v_body := 'Your item has been picked up for replacement processing.';
  elsif new.return_status = 'returned' then
    v_title := 'Replacement item received';
    v_body := 'Your item has been received and verified for replacement.';
  elsif new.return_status = 'refund_completed' then
    v_title := 'Replacement refund processed';
    v_body := 'Refund for your replacement request has been completed.';
  else
    return new;
  end if;

  insert into public.user_notifications (user_id, kind, title, body, order_id)
  values (new.user_id, 'return_refund', v_title, v_body, new.order_id);
  return new;
end;
$$;
