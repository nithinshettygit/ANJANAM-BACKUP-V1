-- Product categories for Shop grid, catalog filters, and admin CRUD.
-- Products still use text `products.category` matching `categories.slug` (lowercase).

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null,

  image_url text null,

  is_active boolean not null default true,
  show_in_shop boolean not null default true,
  display_order integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint categories_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint categories_slug_unique unique (slug)
);

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create index if not exists idx_categories_display_order
  on public.categories (display_order asc, created_at asc);

create index if not exists idx_categories_active_shop
  on public.categories (display_order asc)
  where is_active = true and show_in_shop = true;

alter table public.categories enable row level security;
alter table public.categories force row level security;

-- Storefront: any signed-out or signed-in user can read active categories (filter + references).
drop policy if exists "categories_select_active_public" on public.categories;
create policy "categories_select_active_public"
on public.categories
for select
to anon, authenticated
using (is_active = true);

-- Admins can read all rows (including inactive / hidden-from-shop).
drop policy if exists "categories_select_admin" on public.categories;
create policy "categories_select_admin"
on public.categories
for select
to authenticated
using (public.is_admin());

drop policy if exists "categories_insert_admin" on public.categories;
create policy "categories_insert_admin"
on public.categories
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "categories_update_admin" on public.categories;
create policy "categories_update_admin"
on public.categories
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "categories_delete_admin" on public.categories;
create policy "categories_delete_admin"
on public.categories
for delete
to authenticated
using (public.is_admin());

-- Shop grid: active + show_in_shop + live product counts (active products only).
create or replace view public.v_shop_category_cards as
select
  c.id,
  c.name,
  c.slug,
  c.image_url,
  c.display_order,
  coalesce((
    select count(*)::int
    from public.products p
    where p.is_active = true
      and lower(trim(coalesce(p.category, ''))) = lower(trim(c.slug))
  ), 0) as product_count
from public.categories c
where c.is_active = true and c.show_in_shop = true;

grant select on public.v_shop_category_cards to anon, authenticated;

-- Seed legacy slugs (idempotent).
insert into public.categories (name, slug, image_url, is_active, show_in_shop, display_order)
values
  ('Books', 'books', null, true, true, 0),
  ('Care', 'care', null, true, true, 10),
  ('Food', 'food', null, true, true, 20),
  ('Incense', 'incense', null, true, true, 30),
  ('Tea', 'tea', null, true, true, 40)
on conflict (slug) do nothing;
