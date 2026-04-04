-- Speed up case-insensitive partial title search (ILIKE '%…%') on the storefront.
create extension if not exists pg_trgm;

create index if not exists idx_products_title_trgm
  on public.products
  using gin (title gin_trgm_ops);
