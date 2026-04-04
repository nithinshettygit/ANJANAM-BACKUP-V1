-- Razorpay payment recording: columns + SECURITY DEFINER RPC (users have no direct UPDATE on orders).

alter table public.orders
  add column if not exists payment_status text,
  add column if not exists razorpay_payment_id text;

update public.orders
set payment_status = 'paid'
where payment_status is null;

alter table public.orders
  drop constraint if exists orders_payment_status_check;

alter table public.orders
  add constraint orders_payment_status_check
  check (payment_status in ('pending', 'paid', 'failed'));

alter table public.orders
  alter column payment_status set not null;

alter table public.orders
  alter column payment_status set default 'pending';

create or replace function public.update_order_payment_status(
  p_order_id uuid,
  p_payment_status text,
  p_razorpay_payment_id text default null
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

  if p_payment_status is null or trim(p_payment_status) = '' then
    raise exception 'invalid_payment_status';
  end if;

  if p_payment_status not in ('pending', 'paid', 'failed') then
    raise exception 'invalid_payment_status';
  end if;

  if p_payment_status = 'paid' then
    if p_razorpay_payment_id is null or length(trim(p_razorpay_payment_id)) < 1 then
      raise exception 'razorpay_payment_id_required';
    end if;
  end if;

  update public.orders o
  set
    payment_status = p_payment_status,
    razorpay_payment_id = case
      when p_payment_status = 'paid' then trim(p_razorpay_payment_id)
      else null
    end,
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

revoke all on function public.update_order_payment_status(uuid, text, text) from public;
grant execute on function public.update_order_payment_status(uuid, text, text) to authenticated;
