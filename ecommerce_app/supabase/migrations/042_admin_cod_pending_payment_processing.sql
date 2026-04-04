-- Allow admins to move pending_payment → processing without online payment proof.
-- COD orders may still show payment_method = razorpay if set_order_payment_cod failed or legacy data;
-- online orders remain protected for non-admin updates.

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
  'Validates order status transitions; admins may set pending_payment→processing without gateway payment proof (COD / manual verification).';
