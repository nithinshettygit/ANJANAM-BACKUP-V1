-- Per-product storefront promo (% OFF on product cards). 0 = no badge / no strikethrough.
alter table public.products add column if not exists display_discount_percent integer not null default 0
  check (display_discount_percent >= 0 and display_discount_percent <= 99);

-- One-time backfill for existing rows (still 0 after add column): match old global slider if present, else 17.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'store_settings'
  ) then
    update public.products p
    set display_discount_percent = coalesce(
      (select s.display_discount_percent from public.store_settings s where s.id = 1 limit 1),
      17
    )
    where p.display_discount_percent = 0;
  else
    update public.products
    set display_discount_percent = 17
    where display_discount_percent = 0;
  end if;
end $$;
