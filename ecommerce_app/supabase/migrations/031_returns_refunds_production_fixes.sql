-- Production fixes: refund cap vs line total, orders.return_deadline, replacement orders.

-- ---------------------------------------------------------------------------
-- 1) orders.return_deadline + delivered hook
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists return_deadline timestamptz;

alter table public.orders
  add column if not exists source_return_id uuid references public.returns (id) on delete set null;

create index if not exists idx_orders_source_return_id
  on public.orders (source_return_id)
  where source_return_id is not null;

update public.orders o
set return_deadline = o.delivered_at + interval '7 days'
where lower(trim(o.status)) = 'delivered'
  and o.delivered_at is not null
  and o.return_deadline is null;

update public.orders o
set return_deadline =
  coalesce(o.delivered_at, o.updated_at, o.created_at) + interval '7 days'
where lower(trim(o.status)) = 'delivered'
  and o.return_deadline is null;

create or replace function public.orders_before_set_delivered_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status = 'delivered'
     and (tg_op = 'INSERT' or old.status is distinct from new.status)
     and new.delivered_at is null then
    new.delivered_at := now();
  end if;

  if new.status = 'delivered'
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    new.return_deadline :=
      (coalesce(new.delivered_at, now())) + interval '7 days';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) returns: replacement link + status value
-- ---------------------------------------------------------------------------
alter table public.returns
  add column if not exists replacement_order_id uuid references public.orders (id) on delete set null;

create index if not exists idx_returns_replacement_order_id
  on public.returns (replacement_order_id)
  where replacement_order_id is not null;

alter table public.returns drop constraint if exists returns_return_status_check;

alter table public.returns
  add constraint returns_return_status_check check (
    return_status in (
      'return_requested',
      'return_approved',
      'pickup_scheduled',
      'item_received_warehouse',
      'return_rejected',
      'replacement_in_progress'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) refunds: strict positive amount + trigger vs order line total
-- ---------------------------------------------------------------------------
alter table public.refunds drop constraint if exists refunds_refund_amount_check;

alter table public.refunds
  add constraint refunds_refund_amount_positive check (refund_amount > 0);

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

    if v_return_status <> 'item_received_warehouse' then
      raise exception 'return_not_ready_for_refund';
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

drop trigger if exists trg_refunds_enforce_gate on public.refunds;

create trigger trg_refunds_write_guard
before insert or update on public.refunds
for each row
execute function public.refunds_before_write_guard();

-- ---------------------------------------------------------------------------
-- 4) Replacement order: on approve + return_type = replacement
-- ---------------------------------------------------------------------------
create or replace function public.returns_after_approve_create_replacement()
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

  if new.return_status is distinct from 'return_approved' then
    return new;
  end if;

  if old.return_status = 'return_approved' then
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

drop trigger if exists trg_returns_after_approve_replacement on public.returns;

create trigger trg_returns_after_approve_replacement
after update of return_status on public.returns
for each row
execute function public.returns_after_approve_create_replacement();

-- ---------------------------------------------------------------------------
-- 5) Notifications: replacement_in_progress
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
    -- Replacement flow immediately advances to replacement_in_progress; notify there only.
    if new.return_type = 'replacement' then
      return new;
    end if;
    v_title := 'Return approved';
    v_body := 'Your return was approved. We will coordinate the next steps.';
  elsif new.return_status = 'replacement_in_progress' then
    v_title := 'Replacement order started';
    v_body :=
      'We created a replacement order for you. Open My orders to track the new shipment.';
  elsif new.return_status = 'pickup_scheduled' then
    v_title := 'Pickup scheduled';
    v_body := coalesce(
      nullif(trim(new.pickup_notes), ''),
      'A pickup has been scheduled for your return. Please keep the item packed and ready.'
    );
  elsif new.return_status = 'return_rejected' then
    v_title := 'Return request declined';
    v_body := coalesce(
      nullif(trim(new.rejection_reason), ''),
      'Unfortunately we could not approve this return. Contact support if you have questions.'
    );
  elsif new.return_status = 'item_received_warehouse' then
    v_title := 'Return received';
    v_body := 'We received your item at our warehouse. Refund processing can begin.';
  else
    return new;
  end if;

  insert into public.user_notifications (user_id, kind, title, body, order_id)
  values (new.user_id, 'return_refund', v_title, v_body, new.order_id);

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) create_customer_return: use return_deadline
-- ---------------------------------------------------------------------------
create or replace function public.create_customer_return(
  p_order_item_id uuid,
  p_return_reason text,
  p_return_note text,
  p_return_images text[],
  p_return_type text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_oid uuid;
  v_pid uuid;
  v_order_user uuid;
  v_order_status text;
  v_delivered_at timestamptz;
  v_return_deadline timestamptz;
  v_effective_deadline timestamptz;
  v_return_id uuid;
  v_img_count int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_return_type is null
     or p_return_type not in ('return', 'replacement') then
    raise exception 'invalid_return_type';
  end if;

  if p_return_reason is null
     or p_return_reason not in (
       'damaged_item', 'wrong_product', 'size_issue', 'not_satisfied'
     ) then
    raise exception 'invalid_return_reason';
  end if;

  v_img_count := coalesce(cardinality(p_return_images), 0);
  if v_img_count < 1 then
    raise exception 'return_images_required';
  end if;

  select
    oi.order_id,
    oi.product_id,
    o.user_id,
    o.status,
    o.delivered_at,
    o.return_deadline
  into v_oid, v_pid, v_order_user, v_order_status, v_delivered_at, v_return_deadline
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where oi.id = p_order_item_id;

  if v_oid is null then
    raise exception 'order_item_not_found';
  end if;

  if v_order_user <> v_uid then
    raise exception 'not_authorized';
  end if;

  if lower(trim(v_order_status)) <> 'delivered' then
    raise exception 'order_not_delivered';
  end if;

  v_effective_deadline := coalesce(
    v_return_deadline,
    case
      when v_delivered_at is not null then v_delivered_at + interval '7 days'
      else null
    end
  );

  if v_effective_deadline is null then
    raise exception 'return_deadline_missing';
  end if;

  if now() > v_effective_deadline then
    raise exception 'return_window_expired';
  end if;

  if exists (
    select 1 from public.returns r
    where r.order_item_id = p_order_item_id
      and r.return_status is distinct from 'return_rejected'
  ) then
    raise exception 'return_already_exists';
  end if;

  insert into public.returns (
    order_id,
    user_id,
    product_id,
    order_item_id,
    return_reason,
    return_note,
    return_images,
    return_type,
    return_status
  ) values (
    v_oid,
    v_uid,
    v_pid,
    p_order_item_id,
    p_return_reason,
    nullif(trim(p_return_note), ''),
    p_return_images,
    p_return_type,
    'return_requested'
  )
  returning id into v_return_id;

  return v_return_id;
end;
$$;

comment on column public.orders.return_deadline is
  'Last moment a return may be requested (delivered_at + 7 days). Set when order becomes delivered.';
comment on column public.orders.source_return_id is
  'If this order was created as a replacement shipment, links to the originating return.';
comment on column public.returns.replacement_order_id is
  'Replacement shipment order created when a replacement return is approved.';
