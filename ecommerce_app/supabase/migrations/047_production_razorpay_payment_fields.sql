-- Production Razorpay payment hardening fields and status values.

alter table public.orders
  add column if not exists paid_at timestamptz,
  add column if not exists payment_signature text;

alter table public.orders
  drop constraint if exists orders_payment_status_check;

alter table public.orders
  add constraint orders_payment_status_check
  check (payment_status in ('pending', 'paid', 'failed', 'refunded'));

update public.orders
set paid_at = coalesce(paid_at, payment_verified_at, updated_at, created_at)
where payment_status = 'paid'
  and paid_at is null;

update public.orders
set payment_signature = coalesce(payment_signature, razorpay_signature)
where payment_signature is null
  and razorpay_signature is not null;
