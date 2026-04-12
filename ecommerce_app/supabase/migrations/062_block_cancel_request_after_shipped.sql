-- Customer cancellation requests: only while processing/packed and not yet shipped.
-- Shiprocket (and similar) may set shipped_at before status advances to shipped; block those too.

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
  v_shipped_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select lower(trim(o.status)), o.shipped_at
  into v_status, v_shipped_at
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

  if v_status in ('shipped', 'out_for_delivery', 'delivered') then
    raise exception 'cancellation_request_not_allowed_for_status';
  end if;

  if v_shipped_at is not null then
    raise exception 'cancellation_request_not_allowed_after_shipped';
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

comment on function public.request_cancel_my_order(uuid, text) is
  'Customer requests cancellation while order is processing or packed, not shipped, and shipped_at is unset.';
