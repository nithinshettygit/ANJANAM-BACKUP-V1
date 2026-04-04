-- Store Razorpay Checkout order id (order_xxx) while payment is still pending,
-- after the server creates the order via Razorpay Orders API.

create or replace function public.set_razorpay_checkout_order_id(
  p_order_id uuid,
  p_razorpay_order_id text
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

  if p_razorpay_order_id is null or length(trim(p_razorpay_order_id)) < 1 then
    raise exception 'invalid_razorpay_order_id';
  end if;

  update public.orders o
  set
    razorpay_order_id = trim(p_razorpay_order_id),
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid
    and lower(trim(coalesce(o.payment_method, ''))) = 'razorpay'
    and lower(trim(coalesce(o.payment_status, ''))) in ('pending', 'failed');

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

revoke all on function public.set_razorpay_checkout_order_id(uuid, text) from public;
grant execute on function public.set_razorpay_checkout_order_id(uuid, text) to authenticated;
