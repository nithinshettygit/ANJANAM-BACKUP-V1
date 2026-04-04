-- Admin visibility/management policies for ecommerce admin panel.
-- This keeps end-user restrictions while allowing profiles.role='admin'
-- accounts to read/manage admin data.

alter table public.profiles
  add column if not exists role text default 'user';

update public.profiles
set role = 'user'
where role is null or btrim(role) = '';

create or replace function public.is_admin(uid uuid default auth.uid())
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
      and lower(coalesce(p.role, 'user')) = 'admin'
  );
$$;

grant execute on function public.is_admin(uuid) to authenticated;

-- Ensure RLS is enabled on required tables.
alter table public.products enable row level security;
alter table public.products force row level security;
alter table public.orders enable row level security;
alter table public.orders force row level security;
alter table public.order_items enable row level security;
alter table public.order_items force row level security;
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

drop policy if exists "profiles_select_admin_all" on public.profiles;
create policy "profiles_select_admin_all"
on public.profiles
for select
to authenticated
using (public.is_admin());

drop policy if exists "profiles_update_admin_all" on public.profiles;
create policy "profiles_update_admin_all"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "profiles_insert_admin_all" on public.profiles;
create policy "profiles_insert_admin_all"
on public.profiles
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "profiles_delete_admin_all" on public.profiles;
create policy "profiles_delete_admin_all"
on public.profiles
for delete
to authenticated
using (public.is_admin());

drop policy if exists "products_insert_admin_all" on public.products;
create policy "products_insert_admin_all"
on public.products
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "products_update_admin_all" on public.products;
create policy "products_update_admin_all"
on public.products
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "products_delete_admin_all" on public.products;
create policy "products_delete_admin_all"
on public.products
for delete
to authenticated
using (public.is_admin());

drop policy if exists "orders_select_admin_all" on public.orders;
create policy "orders_select_admin_all"
on public.orders
for select
to authenticated
using (public.is_admin());

drop policy if exists "orders_update_admin_all" on public.orders;
create policy "orders_update_admin_all"
on public.orders
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "orders_insert_admin_all" on public.orders;
create policy "orders_insert_admin_all"
on public.orders
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "orders_delete_admin_all" on public.orders;
create policy "orders_delete_admin_all"
on public.orders
for delete
to authenticated
using (public.is_admin());

drop policy if exists "order_items_select_admin_all" on public.order_items;
create policy "order_items_select_admin_all"
on public.order_items
for select
to authenticated
using (public.is_admin());

drop policy if exists "order_items_insert_admin_all" on public.order_items;
create policy "order_items_insert_admin_all"
on public.order_items
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "order_items_update_admin_all" on public.order_items;
create policy "order_items_update_admin_all"
on public.order_items
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "order_items_delete_admin_all" on public.order_items;
create policy "order_items_delete_admin_all"
on public.order_items
for delete
to authenticated
using (public.is_admin());

-- =========================================================
-- Storage security: product-images bucket
-- =========================================================

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "product_images_public_read" on storage.objects;
create policy "product_images_public_read"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'product-images');

drop policy if exists "product_images_admin_insert" on storage.objects;
create policy "product_images_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and public.is_admin()
);

drop policy if exists "product_images_admin_update" on storage.objects;
create policy "product_images_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and public.is_admin()
)
with check (
  bucket_id = 'product-images'
  and public.is_admin()
);

drop policy if exists "product_images_admin_delete" on storage.objects;
create policy "product_images_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and public.is_admin()
);

-- =========================================================
-- Performance indexes for admin queries
-- =========================================================

alter table public.products
  add column if not exists is_active boolean not null default true;

create index if not exists idx_products_created_at on public.products (created_at desc);
create index if not exists idx_products_category on public.products (category);
create index if not exists idx_products_inventory_count on public.products (inventory_count);
create index if not exists idx_products_is_active on public.products (is_active);

create index if not exists idx_orders_created_at on public.orders (created_at desc);
create index if not exists idx_orders_status on public.orders (status);
create index if not exists idx_orders_user_id on public.orders (user_id);

create index if not exists idx_profiles_role on public.profiles (role);
create index if not exists idx_profiles_full_name on public.profiles (full_name);

-- =========================================================
-- Admin activity logging
-- =========================================================

create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users (id) on delete cascade,
  action text not null,
  entity text not null,
  entity_id text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_admin_logs_admin_id on public.admin_logs (admin_id);
create index if not exists idx_admin_logs_entity on public.admin_logs (entity, entity_id);
create index if not exists idx_admin_logs_created_at on public.admin_logs (created_at desc);

alter table public.admin_logs enable row level security;
alter table public.admin_logs force row level security;

drop policy if exists "admin_logs_select_admin_only" on public.admin_logs;
create policy "admin_logs_select_admin_only"
on public.admin_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin_logs_insert_admin_only" on public.admin_logs;
create policy "admin_logs_insert_admin_only"
on public.admin_logs
for insert
to authenticated
with check (
  public.is_admin()
  and admin_id = auth.uid()
);

