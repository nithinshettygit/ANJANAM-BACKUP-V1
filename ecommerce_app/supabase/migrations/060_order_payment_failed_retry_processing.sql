-- Allow successful Razorpay (or COD/admin) retry after `payment_failed`:
-- 1) Status graph must allow payment_failed → processing.
-- 2) Inventory: reservations are released on pending_payment → payment_failed,
--    so retry cannot use convert_order_reservation_to_deduction alone; use a
--    helper that converts when reservation still exists, else deducts inventory only.

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
  end loop;
end;
$$;

comment on function public.deduct_inventory_for_order_after_failed_payment(uuid) is
  'For payment_failed → processing: deduct stock after reservations may already have been released; '
  'if reservation rows still exist, applies the same inventory+reserved decrement as convert_order_reservation_to_deduction.';

create or replace function public.orders_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select case lower(trim(p_old))
    when 'placed' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'pending' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'pending_payment' then lower(trim(p_new)) in (
      'processing',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'cancel_requested',
      'cancelled'
    )
    when 'payment_failed' then lower(trim(p_new)) in (
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'payment_failed_inventory' then lower(trim(p_new)) = 'payment_failed_inventory'
    when 'out_of_stock_after_payment' then lower(trim(p_new)) = 'out_of_stock_after_payment'
    when 'processing' then lower(trim(p_new)) in ('packed', 'cancel_requested', 'cancelled')
    when 'packed' then lower(trim(p_new)) in ('shipped', 'cancel_requested', 'cancelled')
    when 'shipped' then lower(trim(p_new)) in ('out_for_delivery')
    when 'out_for_delivery' then lower(trim(p_new)) in ('delivered')
    when 'delivered' then lower(trim(p_new)) = 'delivered'
    when 'cancel_requested' then lower(trim(p_new)) in ('cancelled', 'cancel_rejected')
    when 'cancel_rejected' then lower(trim(p_new)) in ('processing', 'packed', 'shipped', 'out_for_delivery')
    when 'cancelled' then lower(trim(p_new)) = 'cancelled'
    else false
  end;
$$;

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
      elsif public.is_admin() then
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

    -- payment_failed → processing (retry succeeded; reservations may already be released)
    if v_o = 'payment_failed' and v_n = 'processing' then
      if coalesce(lower(trim(new.payment_method)), '') = 'cod' then
        perform public.deduct_inventory_for_order_after_failed_payment(new.id);
      elsif public.is_admin() then
        perform public.deduct_inventory_for_order_after_failed_payment(new.id);
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
        perform public.deduct_inventory_for_order_after_failed_payment(new.id);
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

comment on function public.orders_before_write_status() is
  'Validates order status transitions; admins may set pending_payment→processing without gateway payment proof (COD / manual verification). '
  'payment_failed→processing applies paid-order checks and inventory deduction compatible with post-failure reservation release.';
