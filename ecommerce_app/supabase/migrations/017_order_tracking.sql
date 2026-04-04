-- E-commerce order tracking: canonical statuses, history, transitions, shipment fields, in-app notifications.

-- ---------------------------------------------------------------------------
-- 1) Shipment fields on orders
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists tracking_number text,
  add column if not exists courier_name text,
  add column if not exists estimated_delivery_date timestamptz;

-- ---------------------------------------------------------------------------
-- 2) Status history + in-app notifications
-- ---------------------------------------------------------------------------
create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  status text not null,
  updated_by uuid references auth.users (id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_order_status_history_order_created
  on public.order_status_history (order_id, created_at asc);

alter table public.order_status_history enable row level security;
alter table public.order_status_history force row level security;

drop policy if exists "order_status_history_select_own_order" on public.order_status_history;
create policy "order_status_history_select_own_order"
on public.order_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_status_history.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_status_history_select_admin" on public.order_status_history;
create policy "order_status_history_select_admin"
on public.order_status_history
for select
to authenticated
using (public.is_admin());

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null default 'order_status',
  title text not null,
  body text not null,
  order_id uuid references public.orders (id) on delete set null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_notifications_user_created
  on public.user_notifications (user_id, created_at desc);

alter table public.user_notifications enable row level security;
alter table public.user_notifications force row level security;

drop policy if exists "user_notifications_select_own" on public.user_notifications;
create policy "user_notifications_select_own"
on public.user_notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "user_notifications_update_own" on public.user_notifications;
create policy "user_notifications_update_own"
on public.user_notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3) Migrate legacy order statuses → placed | processing | shipped | delivered | cancelled
-- ---------------------------------------------------------------------------
alter table public.orders drop constraint if exists orders_status_check;

update public.orders o
set status = case
  when lower(trim(o.status)) in ('pending', 'placed') then 'placed'
  when lower(trim(o.status)) in ('confirmed', 'authorized', 'paid') then 'placed'
  when lower(trim(o.status)) = 'processing' then 'processing'
  when lower(trim(o.status)) in ('shipped', 'shopped') then 'shipped'
  when lower(trim(o.status)) in ('delivered', 'completed') then 'delivered'
  when lower(trim(o.status)) in ('cancelled', 'canceled', 'refunded', 'failed') then 'cancelled'
  else 'placed'
end;

alter table public.orders
  add constraint orders_status_check check (
    status in ('placed', 'processing', 'shipped', 'delivered', 'cancelled')
  );

alter table public.orders alter column status set default 'placed';

-- ---------------------------------------------------------------------------
-- 4) Backfill history for existing orders (placed at creation + terminal snapshot)
-- ---------------------------------------------------------------------------
insert into public.order_status_history (order_id, status, updated_by, notes, created_at)
select o.id, 'placed', null, null, o.created_at
from public.orders o
where not exists (
  select 1 from public.order_status_history h where h.order_id = o.id
);

insert into public.order_status_history (order_id, status, updated_by, notes, created_at)
select
  o.id,
  o.status,
  null,
  case
    when o.status = 'cancelled' then 'Order cancelled (migrated record).'
    when o.status <> 'placed' then 'Status at migration.'
    else null
  end,
  greatest(o.created_at, coalesce(o.updated_at, o.created_at))
from public.orders o
where o.status <> 'placed'
  and not exists (
    select 1
    from public.order_status_history h
    where h.order_id = o.id
      and h.status = o.status
  );

-- ---------------------------------------------------------------------------
-- 5) Status normalization + transition rules + history + notifications
-- ---------------------------------------------------------------------------
create or replace function public.orders_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select
    case lower(trim(p_old))
      when 'placed' then lower(trim(p_new)) in ('processing', 'cancelled')
      when 'processing' then lower(trim(p_new)) in ('shipped', 'cancelled')
      when 'shipped' then lower(trim(p_new)) = 'delivered'
      when 'delivered' then lower(trim(p_new)) = 'delivered'
      when 'cancelled' then lower(trim(p_new)) = 'cancelled'
      else false
    end;
$$;

create or replace function public.orders_before_write_status()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.status is not null) then
    new.status := lower(trim(new.status));
    if new.status = 'pending' then
      new.status := 'placed';
    end if;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    if not public.orders_valid_status_transition(old.status, new.status) then
      raise exception 'invalid_order_status_transition: % → %', old.status, new.status;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_before_write_status on public.orders;
create trigger trg_orders_before_write_status
before insert or update of status on public.orders
for each row
execute function public.orders_before_write_status();

create or replace function public.orders_after_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notes text;
  v_setting text;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  begin
    v_setting := current_setting('app.order_status_notes', true);
  exception
    when others then
      v_setting := null;
  end;
  v_notes := nullif(trim(coalesce(v_setting, '')), '');

  insert into public.order_status_history (order_id, status, updated_by, notes, created_at)
  values (new.id, new.status, auth.uid(), v_notes, now());

  if new.status = 'processing' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Order confirmed',
      'We are preparing your order.',
      new.id
    );
  elsif new.status = 'shipped' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Order shipped',
      'Your order is on the way.',
      new.id
    );
  elsif new.status = 'delivered' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Order delivered',
      'Your order has been delivered. Thank you for shopping with us!',
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_after_status_change on public.orders;
create trigger trg_orders_after_status_change
after update of status on public.orders
for each row
execute function public.orders_after_status_change();

create or replace function public.orders_after_insert_initial_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.order_status_history (order_id, status, updated_by, notes, created_at)
  values (new.id, new.status, null, null, new.created_at);
  return new;
end;
$$;

drop trigger if exists trg_orders_after_insert_initial_history on public.orders;
create trigger trg_orders_after_insert_initial_history
after insert on public.orders
for each row
execute function public.orders_after_insert_initial_history();

-- ---------------------------------------------------------------------------
-- 6) Checkout: new orders start as placed
-- ---------------------------------------------------------------------------
create or replace function public.place_order_checkout(
  p_currency text,
  p_items jsonb,
  p_shipping jsonb
)
returns table (
  checkout_order_id uuid,
  checkout_user_id uuid,
  checkout_status text,
  checkout_currency text,
  checkout_created_at timestamptz,
  checkout_delivery_fee numeric,
  checkout_subtotal numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
  v_len int;
  i int;
  elem jsonb;
  v_pid uuid;
  v_qty int;
  v_inv int;
  v_urls text[];
  v_subtotal numeric(12,2) := 0;
  v_delivery numeric(12,2) := 0;
  v_fee_setting numeric(12,2);
  v_free_above numeric(12,2);
  v_name text;
  v_phone text;
  v_addr text;
  v_city text;
  v_postal text;
  v_order_currency text;
  v_db_price numeric(12,2);
  v_db_currency text;
  v_db_title text;
  v_is_active boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'empty_cart';
  end if;

  if p_shipping is null or jsonb_typeof(p_shipping) <> 'object' then
    raise exception 'shipping_required';
  end if;

  v_name := trim(coalesce(p_shipping->>'full_name', ''));
  v_phone := trim(coalesce(p_shipping->>'phone', ''));
  v_addr := trim(coalesce(p_shipping->>'address_line', ''));
  v_city := trim(coalesce(p_shipping->>'city', ''));
  v_postal := trim(coalesce(p_shipping->>'postal_code', ''));

  if length(v_name) < 2 then
    raise exception 'invalid_shipping_name';
  end if;
  if v_phone !~ '^\d{10}$' then
    raise exception 'invalid_shipping_phone';
  end if;
  if length(v_addr) < 3 then
    raise exception 'invalid_shipping_address';
  end if;
  if length(v_city) < 2 then
    raise exception 'invalid_shipping_city';
  end if;
  if v_postal !~ '^\d{6}$' then
    raise exception 'invalid_shipping_postal';
  end if;

  v_order_currency := coalesce(nullif(trim(p_currency), ''), 'INR');
  v_len := jsonb_array_length(p_items);

  for i in 0 .. v_len - 1 loop
    elem := p_items->i;
    begin
      v_pid := (elem->>'product_id')::uuid;
    exception
      when invalid_text_representation then
        raise exception 'invalid_product_id';
    end;

    v_qty := (elem->>'quantity')::int;
    if v_qty is null or v_qty < 1 then
      raise exception 'invalid_quantity';
    end if;

    select
      p.inventory_count,
      p.price,
      p.currency,
      p.is_active
    into
      v_inv,
      v_db_price,
      v_db_currency,
      v_is_active
    from public.products p
    where p.id = v_pid
    for update;

    if not found then
      raise exception 'product_not_found';
    end if;

    if not coalesce(v_is_active, false) then
      raise exception 'product_not_available';
    end if;

    if v_inv < v_qty then
      raise exception 'insufficient_inventory';
    end if;

    v_db_currency := coalesce(nullif(trim(v_db_currency), ''), 'INR');
    if v_db_currency <> v_order_currency then
      raise exception 'currency_mismatch';
    end if;

    if v_db_price is null or v_db_price < 0 then
      raise exception 'invalid_product_price';
    end if;

    v_subtotal := v_subtotal + (v_db_price * v_qty);
  end loop;

  select ss.delivery_fee_inr, ss.free_delivery_above_inr
  into v_fee_setting, v_free_above
  from public.store_settings ss
  where ss.id = 1;

  v_fee_setting := coalesce(v_fee_setting, 0);
  if v_free_above is not null and v_subtotal >= v_free_above then
    v_delivery := 0;
  else
    v_delivery := v_fee_setting;
  end if;

  insert into public.orders (
    user_id,
    status,
    currency,
    shipping_full_name,
    shipping_phone,
    shipping_address_line,
    shipping_city,
    shipping_postal_code,
    delivery_fee
  )
  values (
    v_uid,
    'placed',
    v_order_currency,
    v_name,
    v_phone,
    v_addr,
    v_city,
    v_postal,
    v_delivery
  )
  returning public.orders.id into v_order_id;

  for i in 0 .. v_len - 1 loop
    elem := p_items->i;
    v_pid := (elem->>'product_id')::uuid;
    v_qty := (elem->>'quantity')::int;

    update public.products pr
    set inventory_count = pr.inventory_count - v_qty
    where pr.id = v_pid;

    select p.title, p.image_urls, p.price, p.currency
    into v_db_title, v_urls, v_db_price, v_db_currency
    from public.products p
    where p.id = v_pid;

    v_db_currency := coalesce(nullif(trim(v_db_currency), ''), 'INR');

    insert into public.order_items (
      order_id,
      product_id,
      title,
      image_urls,
      unit_price,
      currency,
      quantity
    )
    values (
      v_order_id,
      v_pid,
      coalesce(nullif(trim(v_db_title), ''), '(product)'),
      coalesce(v_urls, array[]::text[]),
      v_db_price,
      v_db_currency,
      v_qty
    );
  end loop;

  return query
  select
    o.id,
    o.user_id,
    o.status,
    o.currency,
    o.created_at,
    o.delivery_fee,
    v_subtotal
  from public.orders o
  where o.id = v_order_id;
end;
$$;

revoke all on function public.place_order_checkout(text, jsonb, jsonb) from public;
grant execute on function public.place_order_checkout(text, jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Reviews: delivered-only eligibility (replaces DELIVERED / COMPLETED)
-- ---------------------------------------------------------------------------
create or replace function public.submit_product_review(
  p_product_id uuid,
  p_rating integer,
  p_review_text text
)
returns public.reviews
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
  v_text text;
  r public.reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating';
  end if;

  v_text := nullif(trim(coalesce(p_review_text, '')), '');
  if v_text is not null and length(v_text) > 1000 then
    raise exception 'review_text_too_long';
  end if;

  if not exists (
    select 1 from public.products p where p.id = p_product_id and p.is_active = true
  ) then
    raise exception 'product_not_found';
  end if;

  select o.id into v_order_id
  from public.orders o
  inner join public.order_items oi on oi.order_id = o.id
  where o.user_id = v_uid
    and oi.product_id = p_product_id
    and o.status = 'delivered'
  order by o.created_at desc
  limit 1;

  if v_order_id is null then
    raise exception 'not_eligible';
  end if;

  insert into public.reviews (
    user_id,
    product_id,
    order_id,
    rating,
    review_text,
    is_verified_purchase,
    is_visible
  )
  values (
    v_uid,
    p_product_id,
    v_order_id,
    p_rating,
    v_text,
    true,
    true
  )
  on conflict (user_id, product_id) do update set
    rating = excluded.rating,
    review_text = excluded.review_text,
    order_id = excluded.order_id,
    is_verified_purchase = true,
    is_visible = true,
    updated_at = now()
  returning * into r;

  return r;
end;
$$;

create or replace function public.get_my_review_eligibility(p_product_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_eligible boolean;
  v_has_review boolean;
begin
  if v_uid is null then
    return jsonb_build_object(
      'signed_in', false,
      'eligible', false,
      'has_review', false
    );
  end if;

  v_eligible := exists (
    select 1
    from public.orders o
    inner join public.order_items oi on oi.order_id = o.id
    where o.user_id = v_uid
      and oi.product_id = p_product_id
      and o.status = 'delivered'
  );

  v_has_review := exists (
    select 1 from public.reviews
    where user_id = v_uid and product_id = p_product_id
  );

  return jsonb_build_object(
    'signed_in', true,
    'eligible', v_eligible,
    'has_review', v_has_review
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8) Customer cancel + admin status (with optional note via session setting)
-- ---------------------------------------------------------------------------
create or replace function public.cancel_my_order(
  p_order_id uuid,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select lower(trim(o.status))
  into v_status
  from public.orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'order_not_found';
  end if;

  if not exists (
    select 1 from public.orders o2
    where o2.id = p_order_id and o2.user_id = v_uid
  ) then
    raise exception 'not_authorized';
  end if;

  if v_status not in ('placed', 'processing') then
    raise exception 'cannot_cancel_shipped_order';
  end if;

  perform set_config(
    'app.order_status_notes',
    coalesce(nullif(trim(p_notes), ''), 'Cancelled by customer.'),
    true
  );

  update public.orders
  set status = 'cancelled'
  where id = p_order_id;

  perform set_config('app.order_status_notes', null, true);
end;
$$;

revoke all on function public.cancel_my_order(uuid, text) from public;
grant execute on function public.cancel_my_order(uuid, text) to authenticated;

create or replace function public.admin_set_order_status(
  p_order_id uuid,
  p_new_status text,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := lower(trim(p_new_status));
begin
  if not public.is_admin() then
    raise exception 'not_authorized';
  end if;

  if v_norm not in ('placed', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'invalid_status';
  end if;

  perform set_config(
    'app.order_status_notes',
    coalesce(nullif(trim(p_notes), ''), ''),
    true
  );

  update public.orders
  set status = v_norm
  where id = p_order_id;

  perform set_config('app.order_status_notes', null, true);
end;
$$;

revoke all on function public.admin_set_order_status(uuid, text, text) from public;
grant execute on function public.admin_set_order_status(uuid, text, text) to authenticated;

comment on table public.order_status_history is 'Append-only audit trail of order.status changes.';
comment on table public.user_notifications is 'In-app notifications; order status changes insert rows for the buyer.';

revoke all on function public.submit_product_review(uuid, integer, text) from public;
grant execute on function public.submit_product_review(uuid, integer, text) to authenticated;

revoke all on function public.get_my_review_eligibility(uuid) from public;
grant execute on function public.get_my_review_eligibility(uuid) to anon, authenticated;
