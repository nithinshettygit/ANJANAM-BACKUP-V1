create or replace function public.admin_approve_replacement_return(
  p_return_id uuid,
  p_schedule_pickup_at timestamptz default null
)
returns table(
  replacement_case_id uuid,
  replacement_order_id uuid,
  pickup_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_return record;
  v_parent public.orders%rowtype;
  v_item record;
  v_case public.replacement_cases%rowtype;
  v_new_replacement_order_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_active_admin(v_uid) then
    raise exception 'not_authorized';
  end if;

  select *
  into v_return
  from public.returns r
  where r.id = p_return_id
  for update;

  if not found then
    raise exception 'return_not_found';
  end if;
  if lower(trim(coalesce(v_return.return_type, ''))) <> 'replacement' then
    raise exception 'not_replacement_return';
  end if;
  if lower(trim(coalesce(v_return.return_status, ''))) not in ('requested', 'approved') then
    raise exception 'invalid_return_state_for_approval';
  end if;

  select *
  into v_parent
  from public.orders
  where id = v_return.order_id
  for update;
  if not found then
    raise exception 'parent_order_not_found';
  end if;

  select *
  into v_item
  from public.order_items oi
  where oi.id = v_return.order_item_id
  for update;
  if not found then
    raise exception 'order_item_not_found';
  end if;

  insert into public.replacement_cases(
    return_id,
    original_order_id,
    original_order_item_id,
    customer_id,
    reason,
    status,
    approved_at
  )
  values(
    v_return.id,
    v_return.order_id,
    v_return.order_item_id,
    v_return.user_id,
    v_return.return_reason,
    'approved',
    now()
  )
  on conflict (return_id) do update
  set status = excluded.status,
      approved_at = coalesce(public.replacement_cases.approved_at, excluded.approved_at),
      updated_at = now()
  returning * into v_case;

  if v_return.replacement_order_id is null then
    insert into public.orders (
      user_id,
      status,
      currency,
      shipping_full_name,
      shipping_phone,
      shipping_address_line,
      shipping_city,
      shipping_postal_code,
      shipping_state,
      delivery_fee,
      customer_email,
      payment_method,
      payment_status,
      razorpay_payment_id,
      razorpay_order_id,
      source_return_id,
      order_kind,
      original_order_id,
      replacement_case_id
    ) values (
      v_parent.user_id,
      'pending_payment',
      v_parent.currency,
      v_parent.shipping_full_name,
      v_parent.shipping_phone,
      v_parent.shipping_address_line,
      v_parent.shipping_city,
      v_parent.shipping_postal_code,
      v_parent.shipping_state,
      0,
      v_parent.customer_email,
      'cod',
      'paid',
      null,
      null,
      v_return.id,
      'replacement',
      v_parent.id,
      v_case.id
    )
    returning id into v_new_replacement_order_id;

    insert into public.order_status_history (
      order_id,
      status,
      updated_by,
      notes,
      created_at
    )
    values (
      v_new_replacement_order_id,
      'pending_payment',
      v_uid,
      'Replacement order: deliver new item and collect old item.',
      now()
    );

    insert into public.order_items (
      order_id,
      product_id,
      title,
      image_urls,
      unit_price,
      currency,
      quantity
    ) values (
      v_new_replacement_order_id,
      v_item.product_id,
      v_item.title,
      coalesce(v_item.image_urls, '{}'::text[]),
      v_item.unit_price,
      v_item.currency,
      v_item.quantity
    );

    update public.products pr
    set inventory_count = pr.inventory_count - v_item.quantity
    where pr.id = v_item.product_id
      and v_item.quantity > 0
      and pr.inventory_count >= v_item.quantity;
    if not found then
      raise exception 'insufficient_inventory_for_replacement';
    end if;

    update public.returns AS r
    set replacement_order_id = v_new_replacement_order_id
    where r.id = v_return.id;
    replacement_order_id := v_new_replacement_order_id;
  else
    replacement_order_id := v_return.replacement_order_id;
  end if;

  update public.replacement_cases AS rc
  set replacement_order_id = coalesce(v_new_replacement_order_id, v_return.replacement_order_id),
      status = 'replacement_order_created',
      updated_at = now()
  where rc.id = v_case.id;

  update public.returns AS r
  set return_status = 'approved',
      updated_at = now()
  where r.id = v_return.id
    and r.return_status <> 'approved';

  insert into public.replacement_pickups(
    replacement_case_id,
    provider,
    status,
    scheduled_at
  ) values (
    v_case.id,
    'manual',
    'pickup_scheduled',
    coalesce(p_schedule_pickup_at, now() + interval '1 day')
  )
  returning id into pickup_id;

  replacement_case_id := v_case.id;
  return next;
end;
$$;

revoke all on function public.admin_approve_replacement_return(uuid, timestamptz) from public;
grant execute on function public.admin_approve_replacement_return(uuid, timestamptz) to authenticated;
