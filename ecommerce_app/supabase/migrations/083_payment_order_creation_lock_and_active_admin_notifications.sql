-- Prevent duplicate Razorpay order creation under concurrent requests.
alter table public.orders
  add column if not exists payment_order_lock_until timestamptz;

create index if not exists idx_orders_payment_order_lock_until
  on public.orders (payment_order_lock_until);

create or replace function public.claim_payment_order_creation_lock(
  p_order_id uuid,
  p_user_id uuid,
  p_lock_seconds integer default 30
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  if p_order_id is null or p_user_id is null then
    raise exception 'invalid_lock_claim_args';
  end if;
  if coalesce(p_lock_seconds, 0) < 1 then
    p_lock_seconds := 30;
  end if;

  update public.orders o
  set
    payment_order_lock_until = now() + make_interval(secs => p_lock_seconds),
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = p_user_id
    and lower(trim(coalesce(o.payment_method, ''))) = 'razorpay'
    and lower(trim(coalesce(o.payment_status, ''))) in ('pending', 'failed')
    and coalesce(trim(o.razorpay_order_id), '') = ''
    and (o.payment_order_lock_until is null or o.payment_order_lock_until < now());

  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

create or replace function public.finalize_payment_order_creation(
  p_order_id uuid,
  p_user_id uuid,
  p_razorpay_order_id text
)
returns table(
  razorpay_order_id text,
  created boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing text;
begin
  if p_order_id is null or p_user_id is null or length(trim(coalesce(p_razorpay_order_id, ''))) < 1 then
    raise exception 'invalid_finalize_args';
  end if;

  update public.orders o
  set
    razorpay_order_id = trim(p_razorpay_order_id),
    payment_status = 'pending',
    razorpay_payment_id = null,
    payment_verified_at = null,
    paid_at = null,
    payment_order_lock_until = null,
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = p_user_id
    and coalesce(trim(o.razorpay_order_id), '') = ''
    and lower(trim(coalesce(o.payment_method, ''))) = 'razorpay'
    and lower(trim(coalesce(o.payment_status, ''))) in ('pending', 'failed');

  if found then
    razorpay_order_id := trim(p_razorpay_order_id);
    created := true;
    return next;
    return;
  end if;

  select trim(coalesce(o.razorpay_order_id, ''))
  into v_existing
  from public.orders o
  where o.id = p_order_id
    and o.user_id = p_user_id
  limit 1;

  if v_existing is null then
    raise exception 'order_not_found_or_forbidden';
  end if;

  razorpay_order_id := v_existing;
  created := false;
  return next;
end;
$$;

create or replace function public.release_payment_order_creation_lock(
  p_order_id uuid,
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  update public.orders
  set
    payment_order_lock_until = null,
    updated_at = now()
  where id = p_order_id
    and user_id = p_user_id;
  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

revoke all on function public.claim_payment_order_creation_lock(uuid, uuid, integer) from public;
revoke all on function public.finalize_payment_order_creation(uuid, uuid, text) from public;
revoke all on function public.release_payment_order_creation_lock(uuid, uuid) from public;
grant execute on function public.claim_payment_order_creation_lock(uuid, uuid, integer) to service_role;
grant execute on function public.finalize_payment_order_creation(uuid, uuid, text) to service_role;
grant execute on function public.release_payment_order_creation_lock(uuid, uuid) to service_role;
