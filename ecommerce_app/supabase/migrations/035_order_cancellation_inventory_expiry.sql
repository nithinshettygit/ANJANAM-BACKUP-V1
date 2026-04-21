-- Production safeguards: cancellation workflow (cancel_requested), inventory reservation,
-- pending-payment expiry, stricter refund support for order cancellations, and inventory triggers.

-- ---------------------------------------------------------------------------
-- 1) Products: reservation + sellable quantity (physical on hand minus reserved)
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists reserved_quantity integer not null default 0
    check (reserved_quantity >= 0);

-- Legacy checkout deducted inventory at order creation. Reconcile open pending_payment
-- orders into the reservation model so available stock stays unchanged.
with pending_by_product as (
  select oi.product_id, sum(oi.quantity)::integer as q
  from public.order_items oi
  inner join public.orders o on o.id = oi.order_id
  where lower(trim(o.status)) = 'pending_payment'
  group by oi.product_id
)
update public.products p
set
  inventory_count = p.inventory_count + pending_by_product.q,
  reserved_quantity = p.reserved_quantity + pending_by_product.q
from pending_by_product
where p.id = pending_by_product.product_id
  and pending_by_product.q > 0;

do $av$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'available_stock'
  ) then
    alter table public.products
      add column available_stock integer
      generated always as (greatest(0, inventory_count - reserved_quantity)) stored;
  end if;
end
$av$;

comment on column public.products.reserved_quantity is
  'Units held for unpaid (pending_payment) orders; sellable qty is available_stock.';
comment on column public.products.available_stock is
  'Generated: max(0, inventory_count - reserved_quantity).';

-- ---------------------------------------------------------------------------
-- 2) Orders: cancellation request metadata
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists pre_cancel_status text,
  add column if not exists cancel_requested_at timestamptz;

alter table public.orders drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check check (
    status in (
      'pending_payment',
      'payment_failed',
      'processing',
      'packed',
      'shipped',
      'out_for_delivery',
      'delivered',
      'cancelled',
      'cancel_requested'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Refunds: optional return for order-level cancellations
-- ---------------------------------------------------------------------------
alter table public.refunds
  add column if not exists refund_source text not null default 'return';

update public.refunds set refund_source = 'return' where refund_source is null;

alter table public.refunds drop constraint if exists refunds_refund_source_check;
alter table public.refunds
  add constraint refunds_refund_source_check check (refund_source in ('return', 'order_cancellation'));

alter table public.refunds alter column return_id drop not null;

alter table public.refunds drop constraint if exists refunds_return_or_cancellation_chk;
alter table public.refunds
  add constraint refunds_return_or_cancellation_chk check (
    (refund_source = 'return' and return_id is not null)
    or (refund_source = 'order_cancellation' and return_id is null)
  );

drop index if exists public.refunds_one_per_return;
create unique index if not exists refunds_one_per_return_id
  on public.refunds (return_id)
  where return_id is not null;

create unique index if not exists refunds_one_cancellation_per_order
  on public.refunds (order_id)
  where refund_source = 'order_cancellation';

-- ---------------------------------------------------------------------------
-- 4) Inventory helpers (security definer for consistent inventory updates)
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
    select oi.product_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;
    update public.products p
    set reserved_quantity = p.reserved_quantity - r.q
    where p.id = r.product_id
      and p.reserved_quantity >= r.q;
    get diagnostics v_upd = row_count;
    if v_upd <> 1 then
      raise exception 'inventory_reservation_release_failed: product %', r.product_id;
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
    select oi.product_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;
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
    select oi.product_id, oi.quantity::integer as q
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    if r.product_id is null or r.q is null or r.q <= 0 then
      continue;
    end if;
    update public.products p
    set inventory_count = p.inventory_count + r.q
    where p.id = r.product_id;
    get diagnostics v_upd = row_count;
    if v_upd <> 1 then
      raise exception 'inventory_restore_failed: product %', r.product_id;
    end if;
  end loop;
end;
$$;

create or replace function public.maybe_initiate_order_cancellation_refund(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_subtotal numeric(12, 2);
  v_total numeric(12, 2);
  v_pay text;
  v_method text;
begin
  select * into v_order from public.orders where id = p_order_id;
  if not found then
    return;
  end if;

  if lower(trim(v_order.status)) <> 'cancelled' then
    return;
  end if;

  v_pay := lower(trim(coalesce(v_order.payment_status, '')));
  if v_pay <> 'paid' then
    return;
  end if;

  if exists (
    select 1 from public.refunds rf
    where rf.order_id = p_order_id
      and rf.refund_source = 'order_cancellation'
  ) then
    return;
  end if;

  v_method := lower(trim(coalesce(v_order.payment_method, '')));
  if v_method <> 'razorpay' then
    return;
  end if;

  if v_order.razorpay_payment_id is null or length(trim(v_order.razorpay_payment_id::text)) < 1 then
    raise exception 'order_cancellation_refund_missing_payment_reference';
  end if;

  select coalesce(round(sum(oi.unit_price * oi.quantity)::numeric, 2), 0)
  into v_subtotal
  from public.order_items oi
  where oi.order_id = p_order_id;

  v_total := round(v_subtotal + coalesce(v_order.delivery_fee, 0), 2);
  if v_total <= 0 then
    raise exception 'order_cancellation_refund_invalid_amount';
  end if;

  insert into public.refunds (
    order_id,
    return_id,
    user_id,
    refund_amount,
    refund_method,
    refund_status,
    payment_transaction_id,
    refund_source
  )
  values (
    p_order_id,
    null,
    v_order.user_id,
    v_total,
    'original_payment',
    'refund_initiated',
    trim(v_order.razorpay_payment_id::text),
    'order_cancellation'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Status transition graph (adds cancel_requested + reject path)
-- ---------------------------------------------------------------------------
create or replace function public.orders_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select case lower(trim(p_old))
    when 'placed' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'processing',
      'cancelled'
    )
    when 'pending' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'processing',
      'cancelled'
    )
    when 'pending_payment' then lower(trim(p_new)) in (
      'processing',
      'payment_failed',
      'cancelled'
    )
    when 'payment_failed' then lower(trim(p_new)) in ('cancelled')
    when 'processing' then lower(trim(p_new)) in ('packed', 'cancel_requested', 'cancelled')
    when 'packed' then lower(trim(p_new)) in ('shipped', 'cancel_requested', 'cancelled')
    when 'cancel_requested' then lower(trim(p_new)) in ('cancelled', 'processing', 'packed')
    when 'shipped' then lower(trim(p_new)) in ('out_for_delivery')
    when 'out_for_delivery' then lower(trim(p_new)) in ('delivered')
    when 'delivered' then lower(trim(p_new)) = 'delivered'
    when 'cancelled' then lower(trim(p_new)) = 'cancelled'
    else false
  end;
$$;

-- ---------------------------------------------------------------------------
-- 6) orders_before_write_status — reservation conversion + cancel_requested reject rules
-- ---------------------------------------------------------------------------
create or replace function public.orders_before_write_status()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_o text;
  v_n text;
  v_cnt int;
  v_pre text;
begin
  if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.status is not null) then
    new.status := lower(trim(new.status));
    if new.status in ('placed', 'pending') then
      new.status := 'pending_payment';
    end if;
  end if;

  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    v_o := lower(trim(old.status));
    v_n := lower(trim(new.status));

    if not public.orders_valid_status_transition(old.status, new.status) then
      raise exception 'invalid_order_status_transition: cannot move order from % to %', old.status, new.status;
    end if;

    -- Reject cancellation: must return to the status the customer had when they requested cancel.
    if v_o = 'cancel_requested' and v_n in ('processing', 'packed') then
      v_pre := nullif(lower(trim(old.pre_cancel_status)), '');
      if v_pre is null or v_pre <> v_n then
        raise exception 'invalid_order_status_transition: cancel_requested → % does not match pre_cancel_status', new.status;
      end if;
      new.pre_cancel_status := null;
      new.cancel_requested_at := null;
    end if;

    -- pending_payment → processing
    if v_o = 'pending_payment' and v_n = 'processing' then
      if coalesce(lower(trim(new.payment_method)), '') = 'cod' then
        perform public.convert_order_reservation_to_deduction(new.id);
      else
        if new.payment_status is distinct from 'paid' then
          raise exception 'order_checklist_payment_not_paid';
        end if;
        if coalesce(lower(trim(new.payment_method)), '') = 'razorpay' then
          if new.razorpay_payment_id is null or length(trim(new.razorpay_payment_id::text)) < 1 then
            raise exception 'order_checklist_missing_razorpay_payment_id';
          end if;
          if new.payment_verified_at is null
             and (new.razorpay_signature is null or length(trim(new.razorpay_signature::text)) < 1) then
            raise exception 'order_checklist_payment_not_verified';
          end if;
        end if;
        perform public.convert_order_reservation_to_deduction(new.id);
      end if;
    end if;

    -- processing → packed
    if v_o = 'processing' and v_n = 'packed' then
      select count(*) into v_cnt from public.order_items oi where oi.order_id = new.id;
      if coalesce(v_cnt, 0) < 1 then
        raise exception 'order_checklist_no_order_items';
      end if;
      if new.shipping_full_name is null or length(trim(new.shipping_full_name::text)) < 1 then
        raise exception 'order_checklist_missing_shipping_address';
      end if;
    end if;

    -- packed → shipped
    if v_o = 'packed' and v_n = 'shipped' then
      if new.tracking_number is null or length(trim(new.tracking_number::text)) < 1 then
        raise exception 'order_checklist_missing_tracking';
      end if;
      if new.courier_name is null or length(trim(new.courier_name::text)) < 1 then
        raise exception 'order_checklist_missing_courier';
      end if;
      if new.package_weight_kg is null then
        raise exception 'order_checklist_missing_package_weight';
      end if;
      if new.package_dimensions_cm is null or length(trim(new.package_dimensions_cm::text)) < 1 then
        raise exception 'order_checklist_missing_package_dimensions';
      end if;
    end if;

    -- out_for_delivery → delivered
    if v_o = 'out_for_delivery' and v_n = 'delivered' then
      if new.delivery_confirmation_at is null then
        new.delivery_confirmation_at := now();
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) AFTER status: release / restore inventory + cancellation refunds
-- ---------------------------------------------------------------------------
create or replace function public.orders_after_status_inventory_effects()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if lower(trim(old.status)) = 'pending_payment' and lower(trim(new.status)) = 'payment_failed' then
    perform public.release_inventory_reservation_for_order(new.id);
  end if;

  if lower(trim(new.status)) = 'cancelled' and lower(trim(old.status)) is distinct from 'cancelled' then
    if lower(trim(old.status)) = 'pending_payment' then
      perform public.release_inventory_reservation_for_order(new.id);
    elsif lower(trim(old.status)) in ('processing', 'packed', 'cancel_requested') then
      perform public.restore_inventory_after_fulfilment_cancel(new.id);
    end if;
    perform public.maybe_initiate_order_cancellation_refund(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_after_status_inventory_effects on public.orders;
create trigger trg_orders_after_status_inventory_effects
after update of status on public.orders
for each row
execute function public.orders_after_status_inventory_effects();

-- ---------------------------------------------------------------------------
-- 8) Refunds guard: return path vs order_cancellation path
-- ---------------------------------------------------------------------------
create or replace function public.refunds_before_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_return_status text;
  v_line_total numeric(12, 2);
  v_order_total numeric(12, 2);
  v_subtotal numeric(12, 2);
  v_o public.orders%rowtype;
  v_src text;
begin
  v_src := lower(trim(coalesce(new.refund_source, 'return')));

  if tg_op = 'INSERT' and v_src = 'order_cancellation' then
    select * into v_o from public.orders where id = new.order_id;
    if not found then
      raise exception 'order_not_found';
    end if;
    if lower(trim(v_o.status)) <> 'cancelled' then
      raise exception 'order_cancellation_refund_order_not_cancelled';
    end if;
    if lower(trim(coalesce(v_o.payment_status, ''))) <> 'paid' then
      raise exception 'order_cancellation_refund_order_not_paid';
    end if;
    if new.refund_method is null or length(trim(new.refund_method::text)) < 1 then
      raise exception 'refund_method_required';
    end if;
    if new.refund_method = 'original_payment' then
      if new.payment_transaction_id is null or length(trim(new.payment_transaction_id::text)) < 1 then
        raise exception 'refund_checklist_payment_reference_required';
      end if;
    end if;

    select coalesce(round(sum(oi.unit_price * oi.quantity)::numeric, 2), 0)
    into v_subtotal
    from public.order_items oi
    where oi.order_id = new.order_id;
    v_order_total := round(v_subtotal + coalesce(v_o.delivery_fee, 0), 2);
    if new.refund_amount > v_order_total then
      raise exception 'refund_exceeds_order_total';
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.return_id is null then
      raise exception 'return_id_required_for_return_refund';
    end if;

    select r.return_status into v_return_status
    from public.returns r
    where r.id = new.return_id;

    if v_return_status is null then
      raise exception 'return_not_found';
    end if;

    if v_return_status not in ('item_received_warehouse', 'inspection_passed') then
      raise exception 'return_not_ready_for_refund';
    end if;

    if new.refund_method is null or length(trim(new.refund_method::text)) < 1 then
      raise exception 'refund_method_required';
    end if;

    if new.refund_method = 'original_payment' then
      if new.payment_transaction_id is null or length(trim(new.payment_transaction_id::text)) < 1 then
        raise exception 'refund_checklist_payment_reference_required';
      end if;
    end if;
  end if;

  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and new.refund_amount is distinct from old.refund_amount) then
    if lower(trim(coalesce(new.refund_source, 'return'))) = 'order_cancellation' then
      select * into v_o from public.orders where id = new.order_id;
      select coalesce(round(sum(oi.unit_price * oi.quantity)::numeric, 2), 0)
      into v_subtotal
      from public.order_items oi
      where oi.order_id = new.order_id;
      v_order_total := round(v_subtotal + coalesce(v_o.delivery_fee, 0), 2);
      if new.refund_amount > v_order_total then
        raise exception 'refund_exceeds_order_total';
      end if;
    else
      select round((oi.unit_price * oi.quantity)::numeric, 2)
      into v_line_total
      from public.returns r
      inner join public.order_items oi on oi.id = r.order_item_id
      where r.id = new.return_id;

      if v_line_total is null then
        raise exception 'return_line_not_found';
      end if;

      if new.refund_amount > v_line_total then
        raise exception 'refund_exceeds_line_total';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9) place_order_checkout — reserve stock instead of deducting immediately
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
    v_qty := (elem->>'quantity')::int;

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

-- ---------------------------------------------------------------------------
-- 10) Customer cancel: instant only for unpaid / failed-payment orders
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

  if v_status in ('processing', 'packed') then
    raise exception 'use_request_cancel_for_processing_or_packed';
  end if;

  if v_status not in ('pending_payment', 'payment_failed') then
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

-- ---------------------------------------------------------------------------
-- 11) Customer: request cancellation (processing / packed)
-- ---------------------------------------------------------------------------
create or replace function public.request_cancel_my_order(
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

  if v_status not in ('processing', 'packed') then
    raise exception 'cancellation_request_not_allowed_for_status';
  end if;

  perform set_config(
    'app.order_status_notes',
    coalesce(nullif(trim(p_notes), ''), 'Cancellation requested by customer.'),
    true
  );

  update public.orders o
  set
    pre_cancel_status = lower(trim(o.status)),
    status = 'cancel_requested',
    cancel_requested_at = now()
  where o.id = p_order_id;

  perform set_config('app.order_status_notes', null, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 12) Admin: approve / reject cancellation request
-- ---------------------------------------------------------------------------
create or replace function public.admin_approve_order_cancellation(
  p_order_id uuid,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int;
begin
  if not public.is_admin() then
    raise exception 'not_authorized';
  end if;

  perform set_config(
    'app.order_status_notes',
    coalesce(nullif(trim(p_notes), ''), 'Cancellation approved by admin.'),
    true
  );

  update public.orders o
  set
    status = 'cancelled',
    pre_cancel_status = null,
    cancel_requested_at = null,
    updated_at = now()
  where o.id = p_order_id
    and lower(trim(o.status)) = 'cancel_requested';

  get diagnostics v_updated = row_count;
  perform set_config('app.order_status_notes', null, true);

  if v_updated <> 1 then
    raise exception 'order_not_cancel_requested_or_missing';
  end if;
end;
$$;

create or replace function public.admin_reject_order_cancellation(
  p_order_id uuid,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pre text;
  v_updated int;
begin
  if not public.is_admin() then
    raise exception 'not_authorized';
  end if;

  select nullif(lower(trim(o.pre_cancel_status)), '')
  into v_pre
  from public.orders o
  where o.id = p_order_id
    and lower(trim(o.status)) = 'cancel_requested'
  for update;

  if v_pre is null then
    raise exception 'order_not_cancel_requested_or_missing';
  end if;

  if v_pre not in ('processing', 'packed') then
    raise exception 'invalid_pre_cancel_status';
  end if;

  perform set_config(
    'app.order_status_notes',
    coalesce(nullif(trim(p_notes), ''), 'Cancellation request declined by admin.'),
    true
  );

  update public.orders o
  set
    status = v_pre,
    pre_cancel_status = null,
    cancel_requested_at = null,
    updated_at = now()
  where o.id = p_order_id
    and lower(trim(o.status)) = 'cancel_requested';

  get diagnostics v_updated = row_count;
  perform set_config('app.order_status_notes', null, true);

  if v_updated <> 1 then
    raise exception 'order_not_cancel_requested_or_missing';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 13) admin_set_order_status — allow cancel_requested target
-- ---------------------------------------------------------------------------
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

  if v_norm not in (
    'pending_payment',
    'payment_failed',
    'processing',
    'packed',
    'shipped',
    'out_for_delivery',
    'delivered',
    'cancelled',
    'cancel_requested'
  ) then
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

-- ---------------------------------------------------------------------------
-- 14) Order notifications — cancel_requested + clearer cancellation copy
-- ---------------------------------------------------------------------------
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
      'We received your payment and are preparing your order.',
      new.id
    );
  elsif new.status = 'packed' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Order packed',
      'Your order has been packed and is ready for dispatch.',
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
  elsif new.status = 'out_for_delivery' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Out for delivery',
      'Your order is out for delivery.',
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
  elsif new.status = 'cancel_requested' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Cancellation pending',
      'We received your cancellation request. Our team will review it shortly.',
      new.id
    );
  elsif new.status = 'cancelled' then
    insert into public.user_notifications (user_id, kind, title, body, order_id)
    values (
      new.user_id,
      'order_status',
      'Order cancelled',
      'This order has been cancelled.',
      new.id
    );
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 15) Expire stale unpaid checkouts (call from Supabase cron / Edge Function with service role)
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_pending_payment_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  update public.orders o
  set status = 'payment_failed', updated_at = now()
  where lower(trim(o.status)) = 'pending_payment'
    and o.created_at < now() - interval '30 minutes';
  get diagnostics n = row_count;
  return coalesce(n, 0);
end;
$$;

revoke all on function public.expire_stale_pending_payment_orders() from public;
grant execute on function public.expire_stale_pending_payment_orders() to service_role;

revoke all on function public.request_cancel_my_order(uuid, text) from public;
grant execute on function public.request_cancel_my_order(uuid, text) to authenticated;

revoke all on function public.admin_approve_order_cancellation(uuid, text) from public;
grant execute on function public.admin_approve_order_cancellation(uuid, text) to authenticated;

revoke all on function public.admin_reject_order_cancellation(uuid, text) from public;
grant execute on function public.admin_reject_order_cancellation(uuid, text) to authenticated;

comment on function public.expire_stale_pending_payment_orders() is
  'Sets pending_payment orders older than 30 minutes to payment_failed and releases reservations. '
  'Schedule with Supabase cron (service role) or call from a scheduled Edge Function.';

comment on function public.request_cancel_my_order(uuid, text) is
  'Customer requests cancellation while order is processing or packed (awaiting admin approval).';
