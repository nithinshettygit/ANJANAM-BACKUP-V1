-- Atomic checkout: create order + order_items and decrement products.inventory_count in one transaction.
-- Regular users cannot UPDATE products (RLS); this function runs as definer and uses auth.uid().
--
-- If this function already exists with a different RETURNS TABLE shape, CREATE OR REPLACE is not
-- allowed (42P13). Drop first, then recreate.
drop function if exists public.place_order_checkout(text, jsonb);

create or replace function public.place_order_checkout(
  p_currency text,
  p_items jsonb
)
-- Names must avoid PL/pgSQL output-param variables that collide with table columns
-- (id, order_id, user_id, status, currency, created_at appear on orders / order_items).
returns table (
  checkout_order_id uuid,
  checkout_user_id uuid,
  checkout_status text,
  checkout_currency text,
  checkout_created_at timestamptz
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
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'empty_cart';
  end if;

  insert into public.orders (user_id, status, currency)
  values (
    v_uid,
    'PENDING',
    coalesce(nullif(trim(p_currency), ''), 'INR')
  )
  returning public.orders.id into v_order_id;

  v_len := jsonb_array_length(p_items);
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
    o.created_at
  from public.orders o
  where o.id = v_order_id;
end;
$$;

revoke all on function public.place_order_checkout(text, jsonb) from public;
grant execute on function public.place_order_checkout(text, jsonb) to authenticated;
