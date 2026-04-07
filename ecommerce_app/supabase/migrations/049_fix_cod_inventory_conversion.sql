-- Fix COD flow so pending_payment -> processing runs inventory conversion trigger.
-- Also backfill existing COD orders stuck in pending_payment.

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

-- Backfill historical COD orders that were left in pending_payment by the old function.
-- The existing orders_before_write_status trigger handles reservation -> deduction.
update public.orders o
set status = 'processing'
where lower(trim(coalesce(o.payment_method, ''))) = 'cod'
  and lower(trim(coalesce(o.status, ''))) = 'pending_payment';
