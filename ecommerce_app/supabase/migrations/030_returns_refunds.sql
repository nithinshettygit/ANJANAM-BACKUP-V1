-- Returns / replacements + refunds, order line ids, delivered_at for return window.

-- ---------------------------------------------------------------------------
-- 1) orders.delivered_at
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists delivered_at timestamptz;

update public.orders o
set delivered_at = h.mx
from (
  select order_id, max(created_at) as mx
  from public.order_status_history
  where lower(trim(status)) = 'delivered'
  group by order_id
) h
where o.id = h.order_id
  and lower(trim(o.status)) = 'delivered'
  and o.delivered_at is null;

update public.orders
set delivered_at = coalesce(delivered_at, updated_at, created_at)
where lower(trim(status)) = 'delivered'
  and delivered_at is null;

create or replace function public.orders_before_set_delivered_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status = 'delivered'
     and (tg_op = 'INSERT' or old.status is distinct from new.status)
     and new.delivered_at is null then
    new.delivered_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_before_delivered_at on public.orders;
create trigger trg_orders_before_delivered_at
before insert or update of status on public.orders
for each row
execute function public.orders_before_set_delivered_at();

-- ---------------------------------------------------------------------------
-- 2) order_items: surrogate id (for returns.order_item_id)
-- ---------------------------------------------------------------------------
alter table public.order_items add column if not exists id uuid;

update public.order_items set id = gen_random_uuid() where id is null;

alter table public.order_items alter column id set default gen_random_uuid();
alter table public.order_items alter column id set not null;

-- Make id uniqueness safe across environments:
-- - if id is already the primary key: no-op
-- - if another primary key already exists: keep it, but enforce unique(id) for FKs
-- - if no primary key exists: use id as primary key
do $$
declare
  v_has_pk_on_id boolean := false;
  v_has_any_pk boolean := false;
  v_has_unique_on_id boolean := false;
begin
  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'order_items'
      and c.contype = 'p'
      and c.conkey = array[
        (select a.attnum
         from pg_attribute a
         where a.attrelid = t.oid
           and a.attname = 'id'
           and not a.attisdropped)
      ]::int2[]
  ) into v_has_pk_on_id;

  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'order_items'
      and c.contype = 'p'
  ) into v_has_any_pk;

  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'order_items'
      and c.contype = 'u'
      and c.conkey = array[
        (select a.attnum
         from pg_attribute a
         where a.attrelid = t.oid
           and a.attname = 'id'
           and not a.attisdropped)
      ]::int2[]
  ) into v_has_unique_on_id;

  if v_has_pk_on_id then
    null;
  elsif v_has_any_pk then
    if not v_has_unique_on_id then
      alter table public.order_items
        add constraint order_items_id_key unique (id);
    end if;
  else
    alter table public.order_items
      add constraint order_items_pkey primary key (id);
  end if;
end
$$;

create unique index if not exists order_items_order_id_product_id_key
  on public.order_items (order_id, product_id);

-- ---------------------------------------------------------------------------
-- 3) returns
-- ---------------------------------------------------------------------------
create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  order_item_id uuid not null references public.order_items (id) on delete restrict,
  return_reason text not null
    check (return_reason in (
      'damaged_item',
      'wrong_product',
      'size_issue',
      'not_satisfied'
    )),
  return_note text,
  return_images text[] not null default '{}'
    check (cardinality(return_images) >= 0),
  return_type text not null
    check (return_type in ('return', 'replacement')),
  return_status text not null default 'return_requested'
    check (return_status in (
      'return_requested',
      'return_approved',
      'pickup_scheduled',
      'item_received_warehouse',
      'return_rejected'
    )),
  pickup_scheduled_at timestamptz,
  pickup_notes text,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists returns_one_active_per_order_item
  on public.returns (order_item_id)
  where return_status is distinct from 'return_rejected';

create index if not exists idx_returns_order_id on public.returns (order_id);
create index if not exists idx_returns_user_id_created on public.returns (user_id, created_at desc);
create index if not exists idx_returns_status on public.returns (return_status);

drop trigger if exists trg_returns_updated_at on public.returns;
create trigger trg_returns_updated_at
before update on public.returns
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4) refunds
-- ---------------------------------------------------------------------------
create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  return_id uuid not null references public.returns (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  refund_amount numeric(12, 2) not null check (refund_amount >= 0),
  refund_method text not null
    check (refund_method in (
      'original_payment',
      'wallet_credit',
      'bank_transfer'
    )),
  refund_status text not null default 'refund_initiated'
    check (refund_status in (
      'refund_initiated',
      'refund_processed',
      'refund_completed'
    )),
  payment_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists refunds_one_per_return on public.refunds (return_id);

create index if not exists idx_refunds_user_created on public.refunds (user_id, created_at desc);
create index if not exists idx_refunds_status on public.refunds (refund_status);

drop trigger if exists trg_refunds_updated_at on public.refunds;
create trigger trg_refunds_updated_at
before update on public.refunds
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5) refund eligibility trigger
-- ---------------------------------------------------------------------------
create or replace function public.refunds_enforce_warehouse_gate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  select r.return_status into v_status
  from public.returns r
  where r.id = new.return_id;

  if v_status is null then
    raise exception 'return_not_found';
  end if;

  if v_status <> 'item_received_warehouse' then
    raise exception 'return_not_ready_for_refund';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_refunds_enforce_gate on public.refunds;
create trigger trg_refunds_enforce_gate
before insert on public.refunds
for each row execute function public.refunds_enforce_warehouse_gate();

-- ---------------------------------------------------------------------------
-- 6) Notifications for returns / refunds
-- ---------------------------------------------------------------------------
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
    'Return request submitted',
    'We received your return request. Our team will review it shortly.',
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

  if new.return_status = 'return_approved' then
    v_title := 'Return approved';
    v_body := 'Your return was approved. We will coordinate the next steps.';
  elsif new.return_status = 'pickup_scheduled' then
    v_title := 'Pickup scheduled';
    v_body := coalesce(
      nullif(trim(new.pickup_notes), ''),
      'A pickup has been scheduled for your return. Please keep the item packed and ready.'
    );
  elsif new.return_status = 'return_rejected' then
    v_title := 'Return request declined';
    v_body := coalesce(
      nullif(trim(new.rejection_reason), ''),
      'Unfortunately we could not approve this return. Contact support if you have questions.'
    );
  elsif new.return_status = 'item_received_warehouse' then
    v_title := 'Return received';
    v_body := 'We received your item at our warehouse. Refund processing can begin.';
  else
    return new;
  end if;

  insert into public.user_notifications (user_id, kind, title, body, order_id)
  values (new.user_id, 'return_refund', v_title, v_body, new.order_id);

  return new;
end;
$$;

drop trigger if exists trg_returns_notify_status on public.returns;
create trigger trg_returns_notify_status
after update of return_status on public.returns
for each row execute function public.notify_return_status_update();

create or replace function public.notify_refund_insert()
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
    'Refund initiated',
    'Your refund has been initiated. It may take a few business days to reflect.',
    new.order_id
  );
  return new;
end;
$$;

drop trigger if exists trg_refunds_notify_insert on public.refunds;
create trigger trg_refunds_notify_insert
after insert on public.refunds
for each row execute function public.notify_refund_insert();

create or replace function public.notify_refund_status_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' or old.refund_status is not distinct from new.refund_status then
    return new;
  end if;

  if new.refund_status = 'refund_completed' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'return_refund',
      'Refund completed',
      'Your refund is complete. Thank you for your patience.',
      new.order_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_refunds_notify_status on public.refunds;
create trigger trg_refunds_notify_status
after update of refund_status on public.refunds
for each row execute function public.notify_refund_status_update();

-- ---------------------------------------------------------------------------
-- 7) RPC: create return (customer)
-- ---------------------------------------------------------------------------
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
  v_img_count int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_return_type is null
     or p_return_type not in ('return', 'replacement') then
    raise exception 'invalid_return_type';
  end if;

  if p_return_reason is null
     or p_return_reason not in (
       'damaged_item', 'wrong_product', 'size_issue', 'not_satisfied'
     ) then
    raise exception 'invalid_return_reason';
  end if;

  v_img_count := coalesce(cardinality(p_return_images), 0);
  if v_img_count < 1 then
    raise exception 'return_images_required';
  end if;

  select oi.order_id, oi.product_id, o.user_id, o.status, o.delivered_at
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

  if lower(trim(v_order_status)) <> 'delivered' then
    raise exception 'order_not_delivered';
  end if;

  if v_delivered_at is null then
    raise exception 'delivery_timestamp_missing';
  end if;

  if v_delivered_at < (now() - interval '7 days') then
    raise exception 'return_window_expired';
  end if;

  if exists (
    select 1 from public.returns r
    where r.order_item_id = p_order_item_id
      and r.return_status is distinct from 'return_rejected'
  ) then
    raise exception 'return_already_exists';
  end if;

  insert into public.returns (
    order_id,
    user_id,
    product_id,
    order_item_id,
    return_reason,
    return_note,
    return_images,
    return_type,
    return_status
  ) values (
    v_oid,
    v_uid,
    v_pid,
    p_order_item_id,
    p_return_reason,
    nullif(trim(p_return_note), ''),
    p_return_images,
    p_return_type,
    'return_requested'
  )
  returning id into v_return_id;

  return v_return_id;
end;
$$;

grant execute on function public.create_customer_return(uuid, text, text, text[], text) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) RLS
-- ---------------------------------------------------------------------------
alter table public.returns enable row level security;
alter table public.returns force row level security;

drop policy if exists "returns_select_own" on public.returns;
create policy "returns_select_own"
on public.returns
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "returns_select_admin" on public.returns;
create policy "returns_select_admin"
on public.returns
for select
to authenticated
using (public.is_admin());

drop policy if exists "returns_update_admin" on public.returns;
create policy "returns_update_admin"
on public.returns
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter table public.refunds enable row level security;
alter table public.refunds force row level security;

drop policy if exists "refunds_select_own" on public.refunds;
create policy "refunds_select_own"
on public.refunds
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "refunds_select_admin" on public.refunds;
create policy "refunds_select_admin"
on public.refunds
for select
to authenticated
using (public.is_admin());

drop policy if exists "refunds_insert_admin" on public.refunds;
create policy "refunds_insert_admin"
on public.refunds
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "refunds_update_admin" on public.refunds;
create policy "refunds_update_admin"
on public.refunds
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 9) Storage: return-images
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('return-images', 'return-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "return_images_public_read" on storage.objects;
create policy "return_images_public_read"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'return-images');

drop policy if exists "return_images_user_insert" on storage.objects;
create policy "return_images_user_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'return-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_images_user_update" on storage.objects;
create policy "return_images_user_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'return-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'return-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_images_user_delete" on storage.objects;
create policy "return_images_user_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'return-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_images_admin_all" on storage.objects;
create policy "return_images_admin_all"
on storage.objects
for all
to authenticated
using (bucket_id = 'return-images' and public.is_admin())
with check (bucket_id = 'return-images' and public.is_admin());

comment on table public.returns is 'Product return / replacement requests; status managed by admins.';
comment on table public.refunds is 'Refunds linked to returns; insert only after warehouse receipt.';
