-- Hotfix apply script: update COD RPC to move pending_payment -> processing.
-- Keep this separate from any backfill to avoid failing on old inconsistent rows.

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
