-- Checkout integrity: subtotal and order_lines use locked [products] row (price, title,
-- image_urls, currency). Rejects inactive products. Prevents client tampering with line pricing.

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

  -- Pass 1: lock rows, enforce catalog state, subtotal from DB prices only.
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
    'PENDING',
    v_order_currency,
    v_name,
    v_phone,
    v_addr,
    v_city,
    v_postal,
    v_delivery
  )
  returning public.orders.id into v_order_id;

  -- Pass 2: decrement stock and snapshot line items from DB (rows still locked).
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
