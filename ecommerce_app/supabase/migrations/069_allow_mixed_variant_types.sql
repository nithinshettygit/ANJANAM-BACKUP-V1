-- Phase 2: allow mixed variant_type values per product
-- (e.g. one product can have Size + Flavor + Color options).

-- Remove the phase-1 guard trigger/function that enforced one variant_type.
drop trigger if exists trg_product_variants_single_type on public.product_variants;
drop function if exists public.enforce_product_variants_single_type();

-- Keep table/function comments aligned with current behavior.
comment on table public.product_variants is
  'Sellable SKUs for a product. A product may have multiple variant_type groups (e.g. size, flavor, color).';
