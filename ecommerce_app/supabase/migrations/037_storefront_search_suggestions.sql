-- Storefront search autocomplete: full-text index on product title (schema uses `title`, not `name`).
-- Prefix ILIKE queries benefit from sequential scan less; GIN tsvector supports contains-style search;
-- combined with existing idx_products_title_trgm (014) for substring ILIKE on listings.

create index if not exists idx_products_name_search
  on public.products
  using gin (to_tsvector('simple', coalesce(title, '')));

-- Optional trending / popular keywords (storefront can use later).
create table if not exists public.search_suggestions (
  id uuid primary key default gen_random_uuid(),
  keyword text not null,
  search_count integer not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists search_suggestions_keyword_lower_unique
  on public.search_suggestions (lower(trim(keyword)));

alter table public.search_suggestions enable row level security;
alter table public.search_suggestions force row level security;

drop policy if exists "search_suggestions_select_public" on public.search_suggestions;
create policy "search_suggestions_select_public"
on public.search_suggestions
for select
to anon, authenticated
using (true);

drop policy if exists "search_suggestions_admin_all" on public.search_suggestions;
create policy "search_suggestions_admin_all"
on public.search_suggestions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());
