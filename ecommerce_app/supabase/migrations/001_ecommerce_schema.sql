-- =========================================================
-- Ecommerce backend schema (idempotent migration)
-- Tables: products, profiles, carts, cart_items, orders, order_items
-- =========================================================

-- Extensions (needed for gen_random_uuid())
create extension if not exists pgcrypto;

-- updated_at trigger helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- 1) products
-- =========================================================
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),

  title text not null,
  description text not null default '',

  price numeric(12,2) not null check (price >= 0),
  currency text not null default 'INR',

  -- Flutter expects: json['image_urls'] as List<String>
  image_urls text[] not null default '{}',

  category text null,

  -- Inventory tracking
  inventory_count integer not null default 0 check (inventory_count >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at
before update on public.products
for each row execute function public.set_updated_at();

-- Useful indexes
create index if not exists idx_products_category on public.products (category);
create index if not exists idx_products_created_at on public.products (created_at desc);
create index if not exists idx_products_inventory_count on public.products (inventory_count);

-- =========================================================
-- 2) profiles
-- =========================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  full_name text null,
  avatar_url text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- =========================================================
-- 3) carts (1 active cart per user)
-- =========================================================
create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (user_id)
);

drop trigger if exists trg_carts_updated_at on public.carts;
create trigger trg_carts_updated_at
before update on public.carts
for each row execute function public.set_updated_at();

create index if not exists idx_carts_user_id on public.carts (user_id);

-- =========================================================
-- 4) cart_items
-- =========================================================
create table if not exists public.cart_items (
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,

  quantity integer not null check (quantity > 0),

  unit_price numeric(12,2) not null check (unit_price >= 0),
  currency text not null default 'INR',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (cart_id, product_id)
);

drop trigger if exists trg_cart_items_updated_at on public.cart_items;
create trigger trg_cart_items_updated_at
before update on public.cart_items
for each row execute function public.set_updated_at();

create index if not exists idx_cart_items_cart_id on public.cart_items (cart_id);
create index if not exists idx_cart_items_product_id on public.cart_items (product_id);

-- =========================================================
-- 5) orders
-- =========================================================
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  status text not null default 'PENDING'
    check (status in (
      'PENDING','CONFIRMED','PROCESSING','SHIPPED','DELIVERED','CANCELLED','REFUNDED',
      'AUTHORIZED','PAID','FAILED'
    )),

  currency text not null default 'INR',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

create index if not exists idx_orders_user_created_at
  on public.orders (user_id, created_at desc);

-- =========================================================
-- 6) order_items
-- =========================================================
create table if not exists public.order_items (
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,

  -- Snapshot fields used by your checkout service
  title text not null,
  image_urls text[] not null default '{}',

  unit_price numeric(12,2) not null check (unit_price >= 0),
  currency text not null default 'INR',

  quantity integer not null check (quantity > 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (order_id, product_id)
);

drop trigger if exists trg_order_items_updated_at on public.order_items;
create trigger trg_order_items_updated_at
before update on public.order_items
for each row execute function public.set_updated_at();

create index if not exists idx_order_items_order_id
  on public.order_items (order_id);
create index if not exists idx_order_items_product_id
  on public.order_items (product_id);

-- =========================================================
-- RLS (Row Level Security) + policies
-- =========================================================

-- PRODUCTS: public read
alter table public.products enable row level security;
alter table public.products force row level security;

drop policy if exists "products_select_public" on public.products;
create policy "products_select_public"
on public.products
for select
to anon, authenticated
using (true);

-- PROFILES: user can read/write own row
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- CARTS: user can manage their own cart(s)
alter table public.carts enable row level security;
alter table public.carts force row level security;

drop policy if exists "carts_select_own" on public.carts;
create policy "carts_select_own"
on public.carts
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "carts_insert_own" on public.carts;
create policy "carts_insert_own"
on public.carts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "carts_update_own" on public.carts;
create policy "carts_update_own"
on public.carts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "carts_delete_own" on public.carts;
create policy "carts_delete_own"
on public.carts
for delete
to authenticated
using (user_id = auth.uid());

-- CART_ITEMS: scoped by cart ownership
alter table public.cart_items enable row level security;
alter table public.cart_items force row level security;

drop policy if exists "cart_items_select_own" on public.cart_items;
create policy "cart_items_select_own"
on public.cart_items
for select
to authenticated
using (
  exists (
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
  exists (
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
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
)
with check (
  exists (
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
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

-- ORDERS: user can manage their own orders
alter table public.orders enable row level security;
alter table public.orders force row level security;

drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
on public.orders
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "orders_update_own" on public.orders;
create policy "orders_update_own"
on public.orders
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "orders_delete_own" on public.orders;
create policy "orders_delete_own"
on public.orders
for delete
to authenticated
using (user_id = auth.uid());

-- ORDER_ITEMS: scoped by order ownership
alter table public.order_items enable row level security;
alter table public.order_items force row level security;

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
      and o.user_id = auth.uid()
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
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_update_own" on public.order_items;
create policy "order_items_update_own"
on public.order_items
for update
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_delete_own" on public.order_items;
create policy "order_items_delete_own"
on public.order_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

-- =========================================================
-- Seed data for products (idempotent UPSERT)
-- =========================================================
insert into public.products
  (id, title, description, price, currency, image_urls, category, inventory_count)
values
  ('11111111-1111-1111-1111-111111111111', 'Organic Green Tea', 'Freshly packed green tea leaves.', 12.50, 'INR',
   array[
     'products/11111111-1111-1111-1111-111111111111/1.jpg',
     'products/11111111-1111-1111-1111-111111111111/2.jpg'
   ],
   'tea', 120),

  ('22222222-2222-2222-2222-222222222222', 'Herbal Honey', 'Raw honey infused with herbs.', 18.00, 'INR',
   array['products/22222222-2222-2222-2222-222222222222/1.jpg'],
   'food', 80),

  ('33333333-3333-3333-3333-333333333333', 'Ayurvedic Soap Bar', 'Gentle soap with natural oils.', 6.75, 'INR',
   array[
     'products/33333333-3333-3333-3333-333333333333/1.jpg',
     'products/33333333-3333-3333-3333-333333333333/2.jpg'
   ],
   'care', 200),

  ('44444444-4444-4444-4444-444444444444', 'Spiritual Incense', 'Slow-burning incense for calm evenings.', 9.99, 'INR',
   array['products/44444444-4444-4444-4444-444444444444/1.jpg'],
   'incense', 150),

  ('55555555-5555-5555-5555-555555555555', 'Copper Water Bottle', 'Insulated copper bottle for daily use.', 29.90, 'INR',
   array['products/55555555-5555-5555-5555-555555555555/1.jpg'],
   'accessories', 40),

  ('66666666-6666-6666-6666-666666666666', 'Sesame Oil', 'Cold-pressed sesame oil.', 14.25, 'INR',
   array['products/66666666-6666-6666-6666-666666666666/1.jpg'],
   'food', 90)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  price = excluded.price,
  currency = excluded.currency,
  image_urls = excluded.image_urls,
  category = excluded.category,
  inventory_count = excluded.inventory_count;

