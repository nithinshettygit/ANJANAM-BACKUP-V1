-- Per-product payment mode: both (COD + online) or online_only.

alter table public.products
  add column if not exists payment_mode text not null default 'both';

alter table public.products
  drop constraint if exists products_payment_mode_check;

alter table public.products
  add constraint products_payment_mode_check
  check (payment_mode in ('both', 'online_only'));

update public.products
set payment_mode = 'both'
where payment_mode is null
   or btrim(payment_mode) = ''
   or lower(payment_mode) not in ('both', 'online_only');

comment on column public.products.payment_mode is
  'both = COD + Razorpay; online_only = Razorpay only.';

create or replace function public.order_allows_cod(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.order_items oi
    inner join public.products p on p.id = oi.product_id
    where oi.order_id = p_order_id
      and lower(coalesce(p.payment_mode, 'both')) = 'online_only'
  );
$$;

revoke all on function public.order_allows_cod(uuid) from public;
grant execute on function public.order_allows_cod(uuid) to authenticated;

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

  if not public.order_allows_cod(p_order_id) then
    raise exception 'cod_not_allowed_for_order';
  end if;

  update public.orders o
  set
    payment_method = 'cod',
    status = case
      when lower(trim(o.status)) = 'pending_payment' then 'processing'
      else o.status
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
