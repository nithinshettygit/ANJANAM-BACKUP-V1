-- Safe admin product deletion:
-- - Hard delete if product has no transactional references
-- - Otherwise archive (inactive + zero stock)
-- Returns: 'deleted' | 'archived'

create or replace function public.admin_delete_product_safe(p_product_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean := false;
  v_referenced boolean := false;
begin
  if not public.is_admin() then
    raise exception 'not_authorized';
  end if;

  select exists(select 1 from public.products p where p.id = p_product_id)
  into v_exists;
  if not v_exists then
    raise exception 'product_not_found';
  end if;

  -- If referenced in orders/returns, keep history and archive instead of deleting.
  select exists(
    select 1
    from public.order_items oi
    where oi.product_id = p_product_id
  )
  into v_referenced;

  if not v_referenced and exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'returns'
  ) then
    select exists(
      select 1
      from public.returns r
      where r.product_id = p_product_id
    )
    into v_referenced;
  end if;

  if v_referenced then
    begin
      update public.products
      set is_active = false,
          inventory_count = 0,
          updated_at = now()
      where id = p_product_id;
    exception
      when undefined_column then
        update public.products
        set inventory_count = 0,
            updated_at = now()
        where id = p_product_id;
    end;
    return 'archived';
  end if;

  delete from public.products where id = p_product_id;
  return 'deleted';
end;
$$;

revoke all on function public.admin_delete_product_safe(uuid) from public;
grant execute on function public.admin_delete_product_safe(uuid) to authenticated;

