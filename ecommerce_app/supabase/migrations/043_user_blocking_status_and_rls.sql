-- Admin-controlled user blocking without deleting data.
-- Adds profile status fields and gates customer policies to active users only.

alter table public.profiles
  add column if not exists status text not null default 'active'
    check (status in ('active', 'blocked'));

alter table public.profiles
  add column if not exists blocked_reason text;

alter table public.profiles
  add column if not exists blocked_at timestamptz;

update public.profiles
set status = 'active'
where status is null
   or btrim(status) = ''
   or lower(status) not in ('active', 'blocked');

create or replace function public.is_user_blocked(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = uid
      and lower(coalesce(p.status, 'active')) = 'blocked'
  );
$$;

create or replace function public.is_user_active(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = uid
      and lower(coalesce(p.status, 'active')) = 'active'
  );
$$;

grant execute on function public.is_user_blocked(uuid) to authenticated;
grant execute on function public.is_user_active(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- profiles (self access only when active)
-- ---------------------------------------------------------------------------
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (
  id = auth.uid()
  and public.is_user_active(auth.uid())
)
with check (
  id = auth.uid()
  and public.is_user_active(auth.uid())
);

-- ---------------------------------------------------------------------------
-- carts / cart_items
-- ---------------------------------------------------------------------------
drop policy if exists "carts_select_own" on public.carts;
create policy "carts_select_own"
on public.carts
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "carts_insert_own" on public.carts;
create policy "carts_insert_own"
on public.carts
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "carts_update_own" on public.carts;
create policy "carts_update_own"
on public.carts
for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
)
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "carts_delete_own" on public.carts;
create policy "carts_delete_own"
on public.carts
for delete
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "cart_items_select_own" on public.cart_items;
create policy "cart_items_select_own"
on public.cart_items
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "cart_items_insert_own" on public.cart_items;
create policy "cart_items_insert_own"
on public.cart_items
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "cart_items_update_own" on public.cart_items;
create policy "cart_items_update_own"
on public.cart_items
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
)
with check (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

drop policy if exists "cart_items_delete_own" on public.cart_items;
create policy "cart_items_delete_own"
on public.cart_items
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- orders / order_items
-- ---------------------------------------------------------------------------
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders
for select
to authenticated
using (
  auth.uid() is not null
  and auth.uid() = user_id
  and public.is_user_active(auth.uid())
);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
on public.orders
for insert
to authenticated
with check (
  auth.uid() is not null
  and auth.uid() = user_id
  and public.is_user_active(auth.uid())
);

drop policy if exists "order_items_select_own" on public.order_items;
create policy "order_items_select_own"
on public.order_items
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
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
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and auth.uid() is not null
      and auth.uid() = o.user_id
  )
);

-- ---------------------------------------------------------------------------
-- user_addresses (account settings)
-- ---------------------------------------------------------------------------
drop policy if exists "user_addresses_select_own" on public.user_addresses;
create policy "user_addresses_select_own"
on public.user_addresses
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "user_addresses_insert_own" on public.user_addresses;
create policy "user_addresses_insert_own"
on public.user_addresses
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "user_addresses_update_own" on public.user_addresses;
create policy "user_addresses_update_own"
on public.user_addresses
for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
)
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists "user_addresses_delete_own" on public.user_addresses;
create policy "user_addresses_delete_own"
on public.user_addresses
for delete
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);
