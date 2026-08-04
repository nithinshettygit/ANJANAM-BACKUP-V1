-- Preserve Razorpay gateway linkage when the client sets payment_status to
-- pending/failed. Clearing razorpay_order_id on soft cancel (web modal dismiss)
-- broke webhook recovery and enabled double-charge on retry.
-- Paid remains forbidden via this RPC (unchanged).

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
  v_status text := lower(trim(coalesce(p_payment_status, '')));
  v_pay_id text := nullif(btrim(coalesce(p_razorpay_payment_id, '')), '');
  v_ord_id text := nullif(btrim(coalesce(p_razorpay_order_id, '')), '');
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if v_status = '' then
    raise exception 'invalid_payment_status';
  end if;

  -- CRITICAL: never allow client RPC to set paid (bypasses Razorpay verify).
  if v_status = 'paid' then
    raise exception 'payment_status_paid_not_allowed_via_rpc';
  end if;

  if v_status not in ('pending', 'failed') then
    raise exception 'invalid_payment_status';
  end if;

  update public.orders o
  set
    payment_status = v_status,
    razorpay_payment_id = coalesce(v_pay_id, o.razorpay_payment_id),
    razorpay_order_id = coalesce(v_ord_id, o.razorpay_order_id),
    payment_verified_at = o.payment_verified_at,
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid
    and lower(coalesce(o.payment_status, '')) <> 'paid';

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

comment on function public.update_order_payment_status(uuid, text, text, text) is
  'Customer-only: set payment_status to pending or failed without clearing razorpay_* ids. Paid is set only by server (Edge/webhook).';
