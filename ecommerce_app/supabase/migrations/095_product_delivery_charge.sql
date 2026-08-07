-- Per-product delivery charge modes (store default / free / custom override).
-- Order-level fee remains a single orders.delivery_fee = max(candidates).

alter table public.products
  add column if not exists delivery_charge_mode text not null default 'default';

alter table public.products
  add column if not exists delivery_charge_inr numeric(12, 2);

alter table public.products
  drop constraint if exists products_delivery_charge_mode_check;

alter table public.products
  add constraint products_delivery_charge_mode_check
  check (delivery_charge_mode in ('default', 'free', 'custom'));

alter table public.products
  drop constraint if exists products_delivery_charge_inr_check;

alter table public.products
  add constraint products_delivery_charge_inr_check
  check (delivery_charge_inr is null or delivery_charge_inr >= 0);

update public.products
set delivery_charge_mode = 'default'
where delivery_charge_mode is null
   or btrim(delivery_charge_mode) = ''
   or lower(delivery_charge_mode) not in ('default', 'free', 'custom');

comment on column public.products.delivery_charge_mode is
  'default = store fee rules; free = no delivery for this product rule; custom = delivery_charge_inr override.';

comment on column public.products.delivery_charge_inr is
  'Used when delivery_charge_mode = custom. Ignored for default/free.';

-- One candidate per product rule (does not sum multi-item shipping).
create or replace function public.product_delivery_fee_candidate(
  p_mode text,
  p_custom_fee numeric,
  p_store_default_fee numeric
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case lower(trim(coalesce(p_mode, 'default')))
    when 'free' then 0::numeric
    when 'custom' then greatest(0::numeric, coalesce(p_custom_fee, 0))
    else greatest(0::numeric, coalesce(p_store_default_fee, 0))
  end;
$$;

revoke all on function public.product_delivery_fee_candidate(text, numeric, numeric) from public;
grant execute on function public.product_delivery_fee_candidate(text, numeric, numeric) to authenticated, anon, service_role;

-- place_order_checkout: same as 068 variants path + max(product delivery candidates).
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
  v_store_default_fee numeric(12,2);
  v_candidate numeric(12,2);
  v_dmode text;
  v_dfee numeric(12,2);
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
  v_store_default_fee := v_fee_setting;
  if v_free_above is not null and v_subtotal >= v_free_above then
    v_store_default_fee := 0;
  end if;

  -- Order fee = max(product candidates). Free product never zeros other products.
  v_delivery := 0;
  for i in 0 .. v_len - 1 loop
    elem := p_items->i;
    begin
      v_pid := (elem->>'product_id')::uuid;
    exception
      when invalid_text_representation then
        v_pid := null;
    end;

    if v_pid is null then
      -- invalid ids already rejected in the pricing loop
      null;
    else
      select
        lower(trim(coalesce(p.delivery_charge_mode, 'default'))),
        p.delivery_charge_inr
      into v_dmode, v_dfee
      from public.products p
      where p.id = v_pid;

      if not found then
        v_dmode := 'default';
        v_dfee := null;
      end if;

      if v_dmode not in ('default', 'free', 'custom') then
        v_dmode := 'default';
      end if;

      v_candidate := public.product_delivery_fee_candidate(v_dmode, v_dfee, v_store_default_fee);
      if v_candidate > v_delivery then
        v_delivery := v_candidate;
      end if;
    end if;
  end loop;

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
