-- Support storefront filters/sorts: active products by price, recency, and stock.
create index if not exists idx_products_active_price
  on public.products (price)
  where is_active = true;

create index if not exists idx_products_active_created_at
  on public.products (created_at desc)
  where is_active = true;

create index if not exists idx_products_active_inventory
  on public.products (inventory_count)
  where is_active = true;
