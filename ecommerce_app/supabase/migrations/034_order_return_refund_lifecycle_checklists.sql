-- Strict order → return → refund lifecycle checklists (production-grade transitions).

-- ---------------------------------------------------------------------------
-- 1) Orders: new columns
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists payment_verified_at timestamptz,
  add column if not exists razorpay_signature text,
  add column if not exists package_weight_kg numeric(12, 3),
  add column if not exists package_dimensions_cm text,
  add column if not exists delivery_confirmation_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2) Returns: new columns + expanded status enum
-- ---------------------------------------------------------------------------
alter table public.returns
  add column if not exists pickup_courier_partner text,
  add column if not exists warehouse_receipt_at timestamptz,
  add column if not exists inspection_notes text;

-- ---------------------------------------------------------------------------
-- 3) Refunds: gateway reference columns
-- ---------------------------------------------------------------------------
alter table public.refunds
  add column if not exists razorpay_refund_id text,
  add column if not exists gateway_refund_status text;

-- ---------------------------------------------------------------------------
-- 3a) Order status transition graph (BEFORE backfill)
-- `trg_orders_before_write_status` from migration 017 is already active; backfill
-- updates must allow legacy placed → pending_payment / payment_failed / processing.
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
      'processing', 'payment_failed', 'cancelled'
    )
    when 'payment_failed' then lower(trim(p_new)) in ('cancelled')
    when 'processing' then lower(trim(p_new)) in ('packed', 'cancelled')
    when 'packed' then lower(trim(p_new)) in ('shipped', 'cancelled')
    when 'shipped' then lower(trim(p_new)) in ('out_for_delivery')
    when 'out_for_delivery' then lower(trim(p_new)) in ('delivered')
    when 'delivered' then lower(trim(p_new)) = 'delivered'
    when 'cancelled' then lower(trim(p_new)) = 'cancelled'
    else false
  end;
$$;

-- ---------------------------------------------------------------------------
-- 3b) Drop old status CHECK before backfill (017 only allows placed, processing, …)
-- Otherwise UPDATE … pending_payment violates orders_status_check.
-- ---------------------------------------------------------------------------
alter table public.orders drop constraint if exists orders_status_check;

-- ---------------------------------------------------------------------------
-- 4) Backfill order.status → new lifecycle
-- ---------------------------------------------------------------------------
update public.orders o
set status = case
  when lower(trim(o.status)) = 'placed'
       and o.payment_method = 'razorpay'
       and o.payment_status = 'pending' then 'pending_payment'
  when lower(trim(o.status)) = 'placed'
       and o.payment_method = 'razorpay'
       and o.payment_status = 'failed' then 'payment_failed'
  when lower(trim(o.status)) = 'placed' then 'processing'
  else lower(trim(o.status))
end
where lower(trim(o.status)) = 'placed';

update public.orders
set payment_verified_at = coalesce(payment_verified_at, updated_at, created_at)
where payment_status = 'paid'
  and payment_verified_at is null;

-- ---------------------------------------------------------------------------
-- 5) Orders: new status CHECK + default (after backfill; no legacy `placed`)
-- ---------------------------------------------------------------------------
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
      'cancelled'
    )
  );

alter table public.orders alter column status set default 'pending_payment';

-- ---------------------------------------------------------------------------
-- 6) Valid graph — `orders_valid_status_transition` defined in section 3a (before backfill)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 7) Returns: status constraint + partial unique index (active returns)
-- ---------------------------------------------------------------------------
alter table public.returns drop constraint if exists returns_return_status_check;

alter table public.returns
  add constraint returns_return_status_check check (
    return_status in (
      'return_requested',
      'return_approved',
      'pickup_scheduled',
      'item_picked_up',
      'item_received_warehouse',
      'inspection_passed',
      'inspection_failed',
      'replacement_in_progress',
      'return_rejected'
    )
  );

drop index if exists public.returns_one_active_per_order_item;

create unique index returns_one_active_per_order_item
  on public.returns (order_item_id)
  where return_status is distinct from 'return_rejected'
    and return_status is distinct from 'inspection_failed';

-- ---------------------------------------------------------------------------
-- 8) Returns: valid transition helper
-- ---------------------------------------------------------------------------
create or replace function public.returns_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select case lower(trim(p_old))
    when 'return_requested' then lower(trim(p_new)) in ('return_approved', 'return_rejected')
    when 'return_approved' then lower(trim(p_new)) in ('pickup_scheduled', 'return_rejected')
    when 'pickup_scheduled' then lower(trim(p_new)) in ('item_picked_up', 'return_rejected')
    when 'item_picked_up' then lower(trim(p_new)) in ('item_received_warehouse')
    when 'item_received_warehouse' then lower(trim(p_new)) in ('inspection_passed', 'inspection_failed')
    when 'inspection_passed' then lower(trim(p_new)) in ('replacement_in_progress')
    when 'inspection_failed' then false
    when 'replacement_in_progress' then false
    when 'return_rejected' then false
    else false
  end;
$$;

-- ---------------------------------------------------------------------------
-- 9) Orders: BEFORE status — normalize + checklist
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
      raise exception 'invalid_order_status_transition: % → %', old.status, new.status;
    end if;

    -- pending_payment → processing
    if v_o = 'pending_payment' and v_n = 'processing' then
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
-- 10) Returns: BEFORE update — transition graph + checklist
-- ---------------------------------------------------------------------------
create or replace function public.returns_before_write_status()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_o text;
  v_n text;
begin
  if tg_op = 'UPDATE' and new.return_status is not null then
    new.return_status := lower(trim(new.return_status));
  end if;

  if tg_op = 'UPDATE' and old.return_status is distinct from new.return_status then
    v_o := lower(trim(old.return_status));
    v_n := lower(trim(new.return_status));

    if not public.returns_valid_status_transition(old.return_status, new.return_status) then
      raise exception 'invalid_return_status_transition: % → %', old.return_status, new.return_status;
    end if;

    if v_o = 'return_approved' and v_n = 'pickup_scheduled' then
      if new.pickup_scheduled_at is null then
        raise exception 'return_checklist_pickup_date_required';
      end if;
      if new.pickup_courier_partner is null or length(trim(new.pickup_courier_partner::text)) < 1 then
        raise exception 'return_checklist_pickup_courier_required';
      end if;
    end if;

    if v_o = 'item_picked_up' and v_n = 'item_received_warehouse' then
      if new.warehouse_receipt_at is null then
        new.warehouse_receipt_at := now();
      end if;
    end if;

    if v_n = 'inspection_failed' then
      if new.rejection_reason is null or length(trim(new.rejection_reason::text)) < 1 then
        raise exception 'return_checklist_inspection_failed_reason_required';
      end if;
    end if;

    if v_o = 'inspection_passed' and v_n = 'replacement_in_progress' then
      if new.return_type is distinct from 'replacement' then
        raise exception 'return_checklist_replacement_type_required';
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_returns_before_write_status on public.returns;
create trigger trg_returns_before_write_status
before insert or update of return_status, pickup_scheduled_at, pickup_courier_partner,
  warehouse_receipt_at, rejection_reason
on public.returns
for each row
execute function public.returns_before_write_status();

-- ---------------------------------------------------------------------------
-- 11) Replacement order: on inspection_passed + replacement (replaces approve trigger)
-- ---------------------------------------------------------------------------
drop trigger if exists trg_returns_after_approve_replacement on public.returns;
drop function if exists public.returns_after_approve_create_replacement();

create or replace function public.returns_after_inspection_replacement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent public.orders%rowtype;
  v_new_order_id uuid;
  v_qty int;
  v_pid uuid;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.return_status is distinct from 'inspection_passed' then
    return new;
  end if;

  if old.return_status = 'inspection_passed' then
    return new;
  end if;

  if new.return_type is distinct from 'replacement' then
    return new;
  end if;

  select * into v_parent from public.orders where id = new.order_id;
  if not found then
    raise exception 'parent_order_not_found';
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
    delivery_fee,
    customer_email,
    payment_method,
    payment_status,
    razorpay_payment_id,
    razorpay_order_id,
    source_return_id
  ) values (
    v_parent.user_id,
    'processing',
    v_parent.currency,
    v_parent.shipping_full_name,
    v_parent.shipping_phone,
    v_parent.shipping_address_line,
    v_parent.shipping_city,
    v_parent.shipping_postal_code,
    coalesce(v_parent.delivery_fee, 0),
    v_parent.customer_email,
    'cod',
    'pending',
    null,
    null,
    new.id
  )
  returning id into v_new_order_id;

  insert into public.order_items (
    order_id,
    product_id,
    title,
    image_urls,
    unit_price,
    currency,
    quantity
  )
  select
    v_new_order_id,
    oi.product_id,
    oi.title,
    oi.image_urls,
    oi.unit_price,
    oi.currency,
    oi.quantity
  from public.order_items oi
  where oi.id = new.order_item_id;

  select oi.quantity, oi.product_id into v_qty, v_pid
  from public.order_items oi
  where oi.id = new.order_item_id;

  if v_pid is not null and v_qty is not null and v_qty > 0 then
    update public.products pr
    set inventory_count = pr.inventory_count - v_qty
    where pr.id = v_pid
      and pr.inventory_count >= v_qty;
    if not found then
      raise exception 'insufficient_inventory_for_replacement';
    end if;
  end if;

  update public.returns r
  set
    replacement_order_id = v_new_order_id,
    return_status = 'replacement_in_progress'
  where r.id = new.id;

  return new;
end;
$$;

create trigger trg_returns_after_inspection_replacement
after update of return_status on public.returns
for each row
execute function public.returns_after_inspection_replacement();

-- ---------------------------------------------------------------------------
-- 12) Refunds: insert gate (warehouse OR inspection passed)
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
begin
  if tg_op = 'INSERT' then
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

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 13) Refunds: status transitions + gateway checklist
-- ---------------------------------------------------------------------------
create or replace function public.refunds_enforce_status_transition()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_method text;
begin
  if old.refund_status is not distinct from new.refund_status then
    return new;
  end if;

  if old.refund_status = 'refund_completed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  if old.refund_status = 'refund_initiated'
     and new.refund_status is distinct from 'refund_processed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  if old.refund_status = 'refund_processed'
     and new.refund_status is distinct from 'refund_completed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  v_method := lower(trim(coalesce(old.refund_method, new.refund_method, '')));

  if old.refund_status = 'refund_initiated' and new.refund_status = 'refund_processed' then
    if v_method = 'original_payment' then
      if new.razorpay_refund_id is null or length(trim(new.razorpay_refund_id::text)) < 1 then
        raise exception 'refund_checklist_razorpay_refund_id_required';
      end if;
    end if;
  end if;

  if old.refund_status = 'refund_processed' and new.refund_status = 'refund_completed' then
    if v_method = 'original_payment' then
      if new.gateway_refund_status is null
         or lower(trim(new.gateway_refund_status::text)) not in ('processed', 'completed') then
        raise exception 'refund_checklist_gateway_refund_not_verified';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 14) Payment RPC: payment_verified_at on paid
-- ---------------------------------------------------------------------------
create or replace function public.update_order_payment_status(
  p_order_id uuid,
  p_payment_status text,
  p_razorpay_payment_id text default null,
  p_razorpay_order_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_updated int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_payment_status is null or trim(p_payment_status) = '' then
    raise exception 'invalid_payment_status';
  end if;

  if p_payment_status not in ('pending', 'paid', 'failed') then
    raise exception 'invalid_payment_status';
  end if;

  if p_payment_status = 'paid' then
    if p_razorpay_payment_id is null or length(trim(p_razorpay_payment_id)) < 1 then
      raise exception 'razorpay_payment_id_required';
    end if;
  end if;

  update public.orders o
  set
    payment_status = p_payment_status,
    razorpay_payment_id = case
      when p_payment_status = 'paid' then trim(p_razorpay_payment_id)
      else null
    end,
    razorpay_order_id = case
      when p_payment_status = 'paid' then
        case
          when p_razorpay_order_id is not null and length(trim(p_razorpay_order_id)) > 0 then
            trim(p_razorpay_order_id)
          else
            o.razorpay_order_id
        end
      else
        null
    end,
    payment_verified_at = case
      when p_payment_status = 'paid' then coalesce(o.payment_verified_at, now())
      else o.payment_verified_at
    end,
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 15) COD: move to processing when switching to COD
-- ---------------------------------------------------------------------------
create or replace function public.set_order_payment_cod(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_updated int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  update public.orders o
  set
    payment_method = 'cod',
    status = case
      when lower(trim(o.status)) = 'pending_payment' then 'processing'
      else o.status
    end,
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 16) place_order_checkout: start as pending_payment
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

-- ---------------------------------------------------------------------------
-- 17) cancel_my_order + admin_set_order_status
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

  if v_status not in ('pending_payment', 'payment_failed', 'processing', 'packed') then
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
    'cancelled'
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
-- 18) Order notifications: packed + out_for_delivery
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
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 19) Return notifications (expanded)
-- ---------------------------------------------------------------------------
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
  elsif new.return_status = 'replacement_in_progress' then
    v_title := 'Replacement order created';
    v_body :=
      'We created a replacement order for you. Open My orders to track the new shipment.';
  elsif new.return_status = 'pickup_scheduled' then
    v_title := 'Pickup scheduled';
    v_body := coalesce(
      nullif(trim(new.pickup_notes), ''),
      'A pickup has been scheduled for your return. Please keep the item packed and ready.'
    );
  elsif new.return_status = 'item_picked_up' then
    v_title := 'Item picked up';
    v_body := 'The return item was picked up and is in transit.';
  elsif new.return_status = 'return_rejected' then
    v_title := 'Return request declined';
    v_body := coalesce(
      nullif(trim(new.rejection_reason), ''),
      'Unfortunately we could not approve this return. Contact support if you have questions.'
    );
  elsif new.return_status = 'item_received_warehouse' then
    v_title := 'Item received at warehouse';
    v_body := 'We received your item at our warehouse. Inspection will follow.';
  elsif new.return_status = 'inspection_passed' then
    v_title := 'Inspection passed';
    v_body := 'Your return passed inspection.';
  elsif new.return_status = 'inspection_failed' then
    v_title := 'Inspection failed';
    v_body := coalesce(
      nullif(trim(new.rejection_reason), ''),
      'Inspection did not pass for this return.'
    );
  else
    return new;
  end if;

  insert into public.user_notifications (user_id, kind, title, body, order_id)
  values (new.user_id, 'return_refund', v_title, v_body, new.order_id);

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 20) Reviews + eligibility: status = delivered
-- ---------------------------------------------------------------------------
-- submit_product_review and get_my_review_eligibility already use status = 'delivered'

comment on function public.orders_before_write_status() is
  'Normalizes legacy statuses and enforces checklist rules before order.status changes.';

-- Catch any legacy "placed" rows after constraint migration
update public.orders
set status = 'pending_payment'
where lower(trim(status)) = 'placed';
