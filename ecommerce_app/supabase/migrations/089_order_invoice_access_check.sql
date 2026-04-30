-- Invoice deep-link access classification for QR-based invoice flow.
--
-- Returns a small, non-sensitive result so the Flutter UI can show:
-- - NOT_LOGGED_IN
-- - UNAUTHORIZED (order belongs to someone else)
-- - ORDER_NOT_FOUND (invalid/expired link)
-- - AUTHORIZED (owner or admin)
--
-- This function is SECURITY DEFINER so it can check existence/ownership
-- without relying on the client-side RLS behavior (which would otherwise
-- make "not found" indistinguishable from "unauthorized").

create or replace function public.check_order_invoice_access(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_order_exists boolean := false;
  v_owner_matches boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('result', 'NOT_LOGGED_IN', 'is_admin', false);
  end if;

  v_is_admin := public.is_admin(v_uid);
  v_order_exists := exists(select 1 from public.orders where id = p_order_id);

  if not v_order_exists then
    return jsonb_build_object('result', 'ORDER_NOT_FOUND', 'is_admin', v_is_admin);
  end if;

  if v_is_admin then
    return jsonb_build_object('result', 'AUTHORIZED', 'is_admin', true);
  end if;

  v_owner_matches := exists(
    select 1
    from public.orders
    where id = p_order_id
      and user_id = v_uid
  );

  if v_owner_matches then
    return jsonb_build_object('result', 'AUTHORIZED', 'is_admin', false);
  end if;

  return jsonb_build_object('result', 'UNAUTHORIZED', 'is_admin', false);
end;
$$;

grant execute on function public.check_order_invoice_access(uuid) to authenticated;

