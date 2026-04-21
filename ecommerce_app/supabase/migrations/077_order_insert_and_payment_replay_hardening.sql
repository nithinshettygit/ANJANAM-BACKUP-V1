-- Production hardening:
-- 1) Block direct client inserts to orders/order_items.
-- 2) Enforce initial order insert invariants.
-- 3) Prevent Razorpay payment-id replay across orders.

drop policy if exists "orders_insert_own" on public.orders;
drop policy if exists "order_items_insert_own" on public.order_items;

create or replace function public.orders_before_insert_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(new.status, 'pending_payment')));
  v_payment_status text := lower(trim(coalesce(new.payment_status, 'pending')));
begin
  if auth.role() = 'authenticated' then
    if v_status not in ('pending_payment') then
      raise exception 'invalid_initial_order_status';
    end if;
    if v_payment_status <> 'pending' then
      raise exception 'invalid_initial_payment_status';
    end if;
    if new.razorpay_payment_id is not null
       or new.razorpay_signature is not null
       or new.payment_signature is not null
       or new.payment_verified_at is not null
       or new.paid_at is not null then
      raise exception 'invalid_initial_payment_fields';
    end if;
    new.status := 'pending_payment';
    new.payment_status := 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_before_insert_guard on public.orders;
create trigger trg_orders_before_insert_guard
before insert on public.orders
for each row
execute function public.orders_before_insert_guard();

create unique index if not exists uq_orders_razorpay_payment_id_not_null
  on public.orders (razorpay_payment_id)
  where razorpay_payment_id is not null;
