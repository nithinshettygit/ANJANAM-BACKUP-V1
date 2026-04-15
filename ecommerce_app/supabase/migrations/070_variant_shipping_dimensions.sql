-- Variant-level shipping metadata (used for courier weight/dim calculations).
alter table public.product_variants
  add column if not exists weight numeric(10, 3)
  check (weight is null or weight > 0);

alter table public.product_variants
  add column if not exists dimensions text;
