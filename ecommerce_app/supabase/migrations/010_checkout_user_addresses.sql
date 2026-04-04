-- Saved shipping addresses + order shipping snapshot + delivery fee settings.

-- ---------------------------------------------------------------------------
-- Store delivery rules (single row id = 1)
-- ---------------------------------------------------------------------------
alter table public.store_settings
  add column if not exists delivery_fee_inr numeric(12,2) not null default 49
    check (delivery_fee_inr >= 0),
  add column if not exists free_delivery_above_inr numeric(12,2)
    check (free_delivery_above_inr is null or free_delivery_above_inr >= 0);

update public.store_settings
set
  delivery_fee_inr = coalesce(delivery_fee_inr, 49),
  free_delivery_above_inr = coalesce(free_delivery_above_inr, 500)
where id = 1;

-- ---------------------------------------------------------------------------
-- Orders: shipping snapshot + delivery charged on this order
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists shipping_full_name text,
  add column if not exists shipping_phone text,
  add column if not exists shipping_address_line text,
  add column if not exists shipping_city text,
  add column if not exists shipping_postal_code text,
  add column if not exists delivery_fee numeric(12,2) not null default 0
    check (delivery_fee >= 0);

-- ---------------------------------------------------------------------------
-- user_addresses
-- ---------------------------------------------------------------------------
create table if not exists public.user_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  address_line text not null,
  city text not null,
  postal_code text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_user_addresses_updated_at on public.user_addresses;
create trigger trg_user_addresses_updated_at
before update on public.user_addresses
for each row execute function public.set_updated_at();

create index if not exists idx_user_addresses_user_id
  on public.user_addresses (user_id, created_at desc);

alter table public.user_addresses enable row level security;
alter table public.user_addresses force row level security;

drop policy if exists "user_addresses_select_own" on public.user_addresses;
create policy "user_addresses_select_own"
on public.user_addresses
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "user_addresses_insert_own" on public.user_addresses;
create policy "user_addresses_insert_own"
on public.user_addresses
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "user_addresses_update_own" on public.user_addresses;
create policy "user_addresses_update_own"
on public.user_addresses
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "user_addresses_delete_own" on public.user_addresses;
create policy "user_addresses_delete_own"
on public.user_addresses
for delete
to authenticated
using (user_id = auth.uid());

-- Only one default address per user (application also enforces).
create or replace function public.user_addresses_single_default()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_default then
    if tg_op = 'INSERT' then
      update public.user_addresses ua
      set is_default = false
      where ua.user_id = new.user_id;
    else
      update public.user_addresses ua
      set is_default = false
      where ua.user_id = new.user_id
        and ua.id <> new.id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_user_addresses_single_default on public.user_addresses;
create trigger trg_user_addresses_single_default
before insert or update on public.user_addresses
for each row
when (new.is_default = true)
execute function public.user_addresses_single_default();

-- ---------------------------------------------------------------------------
-- place_order_checkout: add p_shipping, persist shipping + delivery_fee
-- ---------------------------------------------------------------------------
drop function if exists public.place_order_checkout(text, jsonb);
drop function if exists public.place_order_checkout(text, jsonb, jsonb);

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

  v_len := jsonb_array_length(p_items);
  for i in 0 .. v_len - 1 loop
    elem := p_items->i;
    v_subtotal := v_subtotal + coalesce((elem->>'unit_price')::numeric, 0)
      * greatest(coalesce((elem->>'quantity')::int, 0), 0);
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
    'PENDING',
    coalesce(nullif(trim(p_currency), ''), 'INR'),
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

    if v_qty is null or v_qty < 1 then
      raise exception 'invalid_quantity';
    end if;

    select p.inventory_count
      into v_inv
    from public.products p
    where p.id = v_pid
    for update;

    if not found then
      raise exception 'product_not_found';
    end if;

    if v_inv < v_qty then
      raise exception 'insufficient_inventory';
    end if;

    update public.products pr
    set inventory_count = pr.inventory_count - v_qty
    where pr.id = v_pid;

    select coalesce(
      array(
        select * from jsonb_array_elements_text(coalesce(elem->'image_urls', '[]'::jsonb))
      ),
      array[]::text[]
    ) into v_urls;

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
      coalesce(elem->>'title', ''),
      v_urls,
      (elem->>'unit_price')::numeric,
      coalesce(nullif(trim(elem->>'currency'), ''), 'INR'),
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
