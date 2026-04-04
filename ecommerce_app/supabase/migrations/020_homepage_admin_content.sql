-- Homepage merchandising: hero banners, curated top categories, product spotlight flags.

-- ---------------------------------------------------------------------------
-- Hero banners (image + redirect)
-- ---------------------------------------------------------------------------
create table if not exists public.homepage_hero_banners (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  redirect_type text not null
    check (redirect_type in ('category', 'product', 'collection', 'external_link', 'no_redirect')),
  redirect_value text not null default '',
  sort_order integer not null default 0,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_homepage_hero_banners_updated_at on public.homepage_hero_banners;
create trigger trg_homepage_hero_banners_updated_at
before update on public.homepage_hero_banners
for each row execute function public.set_updated_at();

create index if not exists idx_homepage_hero_banners_enabled_sort
  on public.homepage_hero_banners (sort_order asc, created_at asc)
  where enabled = true;

alter table public.homepage_hero_banners enable row level security;
alter table public.homepage_hero_banners force row level security;

drop policy if exists "homepage_hero_banners_select_storefront" on public.homepage_hero_banners;
create policy "homepage_hero_banners_select_storefront"
on public.homepage_hero_banners
for select
to anon, authenticated
using (enabled = true);

drop policy if exists "homepage_hero_banners_select_admin" on public.homepage_hero_banners;
create policy "homepage_hero_banners_select_admin"
on public.homepage_hero_banners
for select
to authenticated
using (public.is_admin());

drop policy if exists "homepage_hero_banners_insert_admin" on public.homepage_hero_banners;
create policy "homepage_hero_banners_insert_admin"
on public.homepage_hero_banners
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "homepage_hero_banners_update_admin" on public.homepage_hero_banners;
create policy "homepage_hero_banners_update_admin"
on public.homepage_hero_banners
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "homepage_hero_banners_delete_admin" on public.homepage_hero_banners;
create policy "homepage_hero_banners_delete_admin"
on public.homepage_hero_banners
for delete
to authenticated
using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Top categories row (curated icons → category listing)
-- ---------------------------------------------------------------------------
create table if not exists public.homepage_top_categories (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  icon_url text not null,
  category_slug text not null,
  sort_order integer not null default 0,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_homepage_top_categories_updated_at on public.homepage_top_categories;
create trigger trg_homepage_top_categories_updated_at
before update on public.homepage_top_categories
for each row execute function public.set_updated_at();

create index if not exists idx_homepage_top_categories_enabled_sort
  on public.homepage_top_categories (sort_order asc, created_at asc)
  where enabled = true;

alter table public.homepage_top_categories enable row level security;
alter table public.homepage_top_categories force row level security;

drop policy if exists "homepage_top_categories_select_storefront" on public.homepage_top_categories;
create policy "homepage_top_categories_select_storefront"
on public.homepage_top_categories
for select
to anon, authenticated
using (enabled = true);

drop policy if exists "homepage_top_categories_select_admin" on public.homepage_top_categories;
create policy "homepage_top_categories_select_admin"
on public.homepage_top_categories
for select
to authenticated
using (public.is_admin());

drop policy if exists "homepage_top_categories_insert_admin" on public.homepage_top_categories;
create policy "homepage_top_categories_insert_admin"
on public.homepage_top_categories
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "homepage_top_categories_update_admin" on public.homepage_top_categories;
create policy "homepage_top_categories_update_admin"
on public.homepage_top_categories
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "homepage_top_categories_delete_admin" on public.homepage_top_categories;
create policy "homepage_top_categories_delete_admin"
on public.homepage_top_categories
for delete
to authenticated
using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Product flags for home sections
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists is_popular boolean not null default false;
alter table public.products
  add column if not exists is_recommended boolean not null default false;
alter table public.products
  add column if not exists is_festival_special boolean not null default false;

create index if not exists idx_products_popular_active
  on public.products (created_at desc)
  where is_active = true and is_popular = true;

create index if not exists idx_products_recommended_active
  on public.products (created_at desc)
  where is_active = true and is_recommended = true;

create index if not exists idx_products_festival_active
  on public.products (created_at desc)
  where is_active = true and is_festival_special = true;

alter table public.homepage_hero_banners
  drop constraint if exists homepage_hero_banners_redirect_type_check;

alter table public.homepage_hero_banners
  add constraint homepage_hero_banners_redirect_type_check
  check (redirect_type in ('category', 'product', 'collection', 'external_link', 'no_redirect'));
