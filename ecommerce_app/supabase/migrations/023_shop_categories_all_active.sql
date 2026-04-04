-- Align storefront shop logic: list every active category (not gated by show_in_shop).
-- Safe to apply after 022; replaces view definition only.

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
where c.is_active = true;
