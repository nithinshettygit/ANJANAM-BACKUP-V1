-- Production hardening:
-- 1) Atomic auth bridge rate limiting (fail-closed callers)
-- 2) Refund gate status alignment to standardized lifecycle ('returned' only)

create or replace function public.auth_bridge_increment_and_check_rate_limit(
  p_key text,
  p_limit integer default 20,
  p_window_seconds integer default 600
)
returns table (
  allowed boolean,
  attempt_count integer,
  window_started_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_row public.auth_bridge_rate_limits%rowtype;
  v_next_count integer;
  v_next_window timestamptz;
begin
  if p_key is null or length(trim(p_key)) = 0 then
    raise exception 'invalid_rate_limit_key';
  end if;
  if coalesce(p_limit, 0) < 1 then
    raise exception 'invalid_rate_limit_limit';
  end if;
  if coalesce(p_window_seconds, 0) < 1 then
    raise exception 'invalid_rate_limit_window';
  end if;

  insert into public.auth_bridge_rate_limits as rl (
    key,
    window_started_at,
    attempt_count,
    updated_at
  )
  values (trim(p_key), v_now, 0, v_now)
  on conflict (key) do nothing;

  select *
  into v_row
  from public.auth_bridge_rate_limits
  where key = trim(p_key)
  for update;

  if v_row.window_started_at >= (v_now - make_interval(secs => p_window_seconds)) then
    v_next_count := coalesce(v_row.attempt_count, 0) + 1;
    v_next_window := v_row.window_started_at;
  else
    v_next_count := 1;
    v_next_window := v_now;
  end if;

  update public.auth_bridge_rate_limits
  set
    attempt_count = v_next_count,
    window_started_at = v_next_window,
    updated_at = v_now
  where key = trim(p_key);

  allowed := (v_next_count <= p_limit);
  attempt_count := v_next_count;
  window_started_at := v_next_window;
  return next;
end;
$$;

revoke all on function public.auth_bridge_increment_and_check_rate_limit(text, integer, integer) from public;
grant execute on function public.auth_bridge_increment_and_check_rate_limit(text, integer, integer) to service_role;

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

    if lower(trim(v_return_status)) not in ('returned') then
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
