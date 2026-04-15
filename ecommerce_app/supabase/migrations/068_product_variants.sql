-- Phase 1 product variants: single variant_type per product (size OR weight OR color OR flavor).
-- Stock + reservations live on product_variants when rows exist; parent products.* aggregates stay in sync via trigger.

-- ---------------------------------------------------------------------------
-- 1) product_variants
-- ---------------------------------------------------------------------------
create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  variant_type text not null,
  variant_name text not null,
  price numeric(12, 2) not null check (price >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  image_url text not null default '',
  sku text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_variants_variant_type_nonempty check (length(trim(variant_type)) > 0),
  constraint product_variants_variant_name_nonempty check (length(trim(variant_name)) > 0)
);

drop trigger if exists trg_product_variants_updated_at on public.product_variants;
create trigger trg_product_variants_updated_at
before update on public.product_variants
for each row execute function public.set_updated_at();

create index if not exists idx_product_variants_product_id on public.product_variants (product_id);

do $av$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'product_variants'
      and column_name = 'available_stock'
  ) then
    alter table public.product_variants
      add column available_stock integer
      generated always as (greatest(0, stock_quantity - reserved_quantity)) stored;
  end if;
end
$av$;

comment on table public.product_variants is
  'Sellable SKUs for a product (Phase 1: one variant_type dimension per product).';

-- At most one default variant per product.
create unique index if not exists product_variants_one_default_per_product
  on public.product_variants (product_id)
  where is_default = true;

-- ---------------------------------------------------------------------------
-- 2) Enforce single variant_type per product + variant belongs to cart line product
-- ---------------------------------------------------------------------------
create or replace function public.enforce_product_variants_single_type()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_pid uuid;
  v_new_type text;
begin
  v_pid := coalesce(new.product_id, old.product_id);
  v_new_type := lower(trim(coalesce(new.variant_type, '')));

  if v_pid is not null and tg_op in ('INSERT', 'UPDATE') and new.variant_type is not null then
    if exists (
      select 1
      from public.product_variants pv
      where pv.product_id = new.product_id
        and pv.id is distinct from new.id
        and lower(trim(pv.variant_type)) is distinct from v_new_type
    ) then
      raise exception 'product_variants_mixed_types: product % may only use one variant_type', new.product_id;
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_product_variants_single_type on public.product_variants;
create trigger trg_product_variants_single_type
before insert or update of variant_type, product_id on public.product_variants
for each row execute function public.enforce_product_variants_single_type();

create or replace function public.sync_product_inventory_from_variants(p_product_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_sum_stock int;
  v_sum_reserved int;
  v_min_price numeric(12, 2);
begin
  if not exists (
    select 1 from public.product_variants pv0 where pv0.product_id = p_product_id
  ) then
    -- Variant rows removed; leave products.* as-is for legacy/manual inventory.
    return;
  end if;

  select
    coalesce(sum(pv.stock_quantity), 0)::integer,
    coalesce(sum(pv.reserved_quantity), 0)::integer,
    min(pv.price)
  into v_sum_stock, v_sum_reserved, v_min_price
  from public.product_variants pv
  where pv.product_id = p_product_id;

  update public.products p
  set
    inventory_count = v_sum_stock,
    reserved_quantity = v_sum_reserved,
    price = coalesce(v_min_price, p.price)
  where p.id = p_product_id;
end;
$$;

create or replace function public.trg_product_variants_sync_parent()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_pid uuid;
begin
  v_pid := coalesce(new.product_id, old.product_id);
  if v_pid is not null then
    perform public.sync_product_inventory_from_variants(v_pid);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_product_variants_sync_parent_aiud on public.product_variants;
create trigger trg_product_variants_sync_parent_aiud
after insert or update or delete on public.product_variants
for each row execute function public.trg_product_variants_sync_parent();

-- ---------------------------------------------------------------------------
-- 3) Optional base_price on products (listing / reference; storefront still uses price)
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists base_price numeric(12, 2)
  check (base_price is null or base_price >= 0);

-- ---------------------------------------------------------------------------
-- 4) cart_items: allow multiple lines per product (different variants)
-- ---------------------------------------------------------------------------
alter table public.cart_items
  add column if not exists variant_id uuid references public.product_variants (id) on delete restrict;

alter table public.cart_items
  add column if not exists id uuid default gen_random_uuid();

update public.cart_items set id = gen_random_uuid() where id is null;

alter table public.cart_items alter column id set not null;
alter table public.cart_items alter column id set default gen_random_uuid();

alter table public.cart_items drop constraint if exists cart_items_pkey;

alter table public.cart_items add primary key (id);

create unique index if not exists cart_items_cart_product_variant_uid
  on public.cart_items (cart_id, product_id, variant_id)
  nulls not distinct;

create index if not exists idx_cart_items_variant_id on public.cart_items (variant_id);

-- ---------------------------------------------------------------------------
-- 5) order_items: optional variant + relax uniqueness for multi-variant orders
-- ---------------------------------------------------------------------------
alter table public.order_items
  add column if not exists variant_id uuid references public.product_variants (id) on delete restrict;

drop index if exists public.order_items_order_id_product_id_key;

create unique index if not exists order_items_order_product_variant_uid
  on public.order_items (order_id, product_id, variant_id)
  nulls not distinct;

create index if not exists idx_order_items_variant_id on public.order_items (variant_id);

-- ---------------------------------------------------------------------------
-- 6) Inventory helpers — variant-aware
-- ---------------------------------------------------------------------------
create or replace function public.release_inventory_reservation_for_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_upd int;
begin
  for r in
    select oi.product_id, oi.variant_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;

    if r.variant_id is not null then
      update public.product_variants pv
      set reserved_quantity = pv.reserved_quantity - r.q
      where pv.id = r.variant_id
        and pv.reserved_quantity >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_release_failed: variant %', r.variant_id;
      end if;
    else
      update public.products p
      set reserved_quantity = p.reserved_quantity - r.q
      where p.id = r.product_id
        and p.reserved_quantity >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_release_failed: product %', r.product_id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.convert_order_reservation_to_deduction(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_upd int;
begin
  for r in
    select oi.product_id, oi.variant_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;

    if r.variant_id is not null then
      update public.product_variants pv
      set
        stock_quantity = pv.stock_quantity - r.q,
        reserved_quantity = pv.reserved_quantity - r.q
      where pv.id = r.variant_id
        and pv.reserved_quantity >= r.q
        and pv.stock_quantity >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_convert_failed: variant %', r.variant_id;
      end if;
    else
      update public.products p
      set
        inventory_count = p.inventory_count - r.q,
        reserved_quantity = p.reserved_quantity - r.q
      where p.id = r.product_id
        and p.reserved_quantity >= r.q
        and p.inventory_count >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_convert_failed: product %', r.product_id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.restore_inventory_after_fulfilment_cancel(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_upd int;
begin
  for r in
    select oi.product_id, oi.variant_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;

    if r.variant_id is not null then
      update public.product_variants pv
      set stock_quantity = pv.stock_quantity + r.q
      where pv.id = r.variant_id;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_restore_failed: variant %', r.variant_id;
      end if;
    else
      update public.products p
      set inventory_count = p.inventory_count + r.q
      where p.id = r.product_id;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_restore_failed: product %', r.product_id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.deduct_inventory_for_order_after_failed_payment(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_upd int;
begin
  for r in
    select oi.product_id, oi.variant_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;

    if r.variant_id is not null then
      update public.product_variants pv
      set
        stock_quantity = pv.stock_quantity - r.q,
        reserved_quantity = pv.reserved_quantity - r.q
      where pv.id = r.variant_id
        and pv.reserved_quantity >= r.q
        and pv.stock_quantity >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd = 1 then
        continue;
      end if;

      update public.product_variants pv
      set stock_quantity = pv.stock_quantity - r.q
      where pv.id = r.variant_id
        and pv.stock_quantity >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_convert_failed: variant %', r.variant_id;
      end if;
    else
      update public.products p
      set
        inventory_count = p.inventory_count - r.q,
        reserved_quantity = p.reserved_quantity - r.q
      where p.id = r.product_id
        and p.reserved_quantity >= r.q
        and p.inventory_count >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd = 1 then
        continue;
      end if;

      update public.products p
      set inventory_count = p.inventory_count - r.q
      where p.id = r.product_id
        and p.inventory_count >= r.q;
      get diagnostics v_upd = row_count;
      if v_upd <> 1 then
        raise exception 'inventory_reservation_convert_failed: product %', r.product_id;
      end if;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) place_order_checkout — variant lines reserve variant stock
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
  v_vid uuid;
  v_qty int;
  v_avail int;
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
  v_has_variants boolean;
  v_vname text;
  v_vimg text;
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

    v_vid := null;
    if elem ? 'variant_id' and nullif(trim(elem->>'variant_id'), '') is not null then
      begin
        v_vid := (elem->>'variant_id')::uuid;
      exception
        when invalid_text_representation then
          raise exception 'invalid_variant_id';
      end;
    end if;

    v_qty := (elem->>'quantity')::int;
    if v_qty is null or v_qty < 1 then
      raise exception 'invalid_quantity';
    end if;

    select exists (select 1 from public.product_variants pv where pv.product_id = v_pid)
    into v_has_variants;

    if v_has_variants then
      if v_vid is null then
        raise exception 'variant_required';
      end if;

      select
        greatest(0, pv.stock_quantity - pv.reserved_quantity),
        pv.price,
        p.currency,
        p.is_active,
        p.title,
        pv.variant_name,
        nullif(trim(pv.image_url), '')
      into
        v_avail,
        v_db_price,
        v_db_currency,
        v_is_active,
        v_db_title,
        v_vname,
        v_vimg
      from public.product_variants pv
      inner join public.products p on p.id = pv.product_id
      where pv.id = v_vid
        and pv.product_id = v_pid
      for update of pv;

      if not found then
        raise exception 'variant_not_found';
      end if;

      if not coalesce(v_is_active, false) then
        raise exception 'product_not_available';
      end if;

      if v_avail < v_qty then
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
    else
      if v_vid is not null then
        raise exception 'variant_not_applicable';
      end if;

      select
        greatest(0, p.inventory_count - p.reserved_quantity),
        p.price,
        p.currency,
        p.is_active
      into
        v_avail,
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

      if v_avail < v_qty then
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
    end if;
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
    'pending_payment',
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
    v_vid := null;
    if elem ? 'variant_id' and nullif(trim(elem->>'variant_id'), '') is not null then
      v_vid := (elem->>'variant_id')::uuid;
    end if;
    v_qty := (elem->>'quantity')::int;

    select exists (select 1 from public.product_variants pv where pv.product_id = v_pid)
    into v_has_variants;

    if v_has_variants then
      update public.product_variants pv
      set reserved_quantity = pv.reserved_quantity + v_qty
      where pv.id = v_vid
        and pv.product_id = v_pid
        and greatest(0, pv.stock_quantity - pv.reserved_quantity) >= v_qty;

      if not found then
        raise exception 'insufficient_inventory';
      end if;

      select
        p.title,
        p.image_urls,
        pv.price,
        p.currency,
        pv.variant_name,
        nullif(trim(pv.image_url), '')
      into v_db_title, v_urls, v_db_price, v_db_currency, v_vname, v_vimg
      from public.products p
      inner join public.product_variants pv on pv.id = v_vid and pv.product_id = p.id
      where p.id = v_pid;

      v_db_currency := coalesce(nullif(trim(v_db_currency), ''), 'INR');

      if v_vimg is not null and length(v_vimg) > 0 then
        v_urls := array[v_vimg];
      end if;

      insert into public.order_items (
        order_id,
        product_id,
        variant_id,
        title,
        image_urls,
        unit_price,
        currency,
        quantity
      )
      values (
        v_order_id,
        v_pid,
        v_vid,
        coalesce(nullif(trim(v_db_title), ''), '(product)') || ' · ' || coalesce(nullif(trim(v_vname), ''), 'variant'),
        coalesce(v_urls, array[]::text[]),
        v_db_price,
        v_db_currency,
        v_qty
      );
    else
      update public.products pr
      set reserved_quantity = pr.reserved_quantity + v_qty
      where pr.id = v_pid
        and greatest(0, pr.inventory_count - pr.reserved_quantity) >= v_qty;

      if not found then
        raise exception 'insufficient_inventory';
      end if;

      select p.title, p.image_urls, p.price, p.currency
      into v_db_title, v_urls, v_db_price, v_db_currency
      from public.products p
      where p.id = v_pid;

      v_db_currency := coalesce(nullif(trim(v_db_currency), ''), 'INR');

      insert into public.order_items (
        order_id,
        product_id,
        variant_id,
        title,
        image_urls,
        unit_price,
        currency,
        quantity
      )
      values (
        v_order_id,
        v_pid,
        null,
        coalesce(nullif(trim(v_db_title), ''), '(product)'),
        coalesce(v_urls, array[]::text[]),
        v_db_price,
        v_db_currency,
        v_qty
      );
    end if;
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
-- 8) RLS: product_variants (public read, admin write)
-- ---------------------------------------------------------------------------
alter table public.product_variants enable row level security;
alter table public.product_variants force row level security;

drop policy if exists "product_variants_select_public" on public.product_variants;
create policy "product_variants_select_public"
on public.product_variants
for select
to anon, authenticated
using (true);

drop policy if exists "product_variants_insert_admin" on public.product_variants;
create policy "product_variants_insert_admin"
on public.product_variants
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "product_variants_update_admin" on public.product_variants;
create policy "product_variants_update_admin"
on public.product_variants
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "product_variants_delete_admin" on public.product_variants;
create policy "product_variants_delete_admin"
on public.product_variants
for delete
to authenticated
using (public.is_admin());
