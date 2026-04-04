-- Order RLS audit: enforce read isolation via auth.uid() = orders.user_id and
-- remove client UPDATE/DELETE on orders / order_items (fraud / data integrity).
--
-- SELECT: users only see rows for their own user_id. Admins keep full access via
--         existing policies in 002_admin_rls_policies.sql (OR-combined).
-- INSERT: kept for authenticated users matching user_id (legacy checkout fallback
--         and any path where RLS applies as the invoker).
-- UPDATE/DELETE (orders, order_items): only admins (existing *_admin_* policies)
--         or SECURITY DEFINER RPC (place_order_checkout) as applicable.

-- ---------------------------------------------------------------------------
-- orders (authenticated "own" policies)
-- ---------------------------------------------------------------------------
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders
for select
to authenticated
using (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
on public.orders
for insert
to authenticated
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "orders_update_own" on public.orders;
drop policy if exists "orders_delete_own" on public.orders;

-- ---------------------------------------------------------------------------
-- order_items (scoped to parent order ownership)
-- ---------------------------------------------------------------------------
drop policy if exists "order_items_select_own" on public.order_items;
create policy "order_items_select_own"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and auth.uid() is not null
      and auth.uid() = o.user_id
  )
);

drop policy if exists "order_items_insert_own" on public.order_items;
create policy "order_items_insert_own"
on public.order_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and auth.uid() is not null
      and auth.uid() = o.user_id
  )
);

drop policy if exists "order_items_update_own" on public.order_items;
drop policy if exists "order_items_delete_own" on public.order_items;
