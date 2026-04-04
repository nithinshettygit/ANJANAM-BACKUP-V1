-- COD vs online: persist payment_method; RPC for buyer to mark COD after checkout.

alter table public.orders
  add column if not exists payment_method text;

update public.orders
set payment_method = 'razorpay'
where payment_method is null;

alter table public.orders
  drop constraint if exists orders_payment_method_check;

alter table public.orders
  add constraint orders_payment_method_check
  check (payment_method in ('razorpay', 'cod'));

alter table public.orders
  alter column payment_method set default 'razorpay';

alter table public.orders
  alter column payment_method set not null;

create or replace function public.set_order_payment_cod(p_order_id uuid)
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

  update public.orders o
  set
    payment_method = 'cod',
    updated_at = now()
  where o.id = p_order_id
    and o.user_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'order_not_found_or_forbidden';
  end if;
end;
$$;

revoke all on function public.set_order_payment_cod(uuid) from public;
grant execute on function public.set_order_payment_cod(uuid) to authenticated;
