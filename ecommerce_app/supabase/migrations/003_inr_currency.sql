-- App uses Indian Rupees (INR) only. Align defaults and migrate legacy USD rows.

alter table public.products alter column currency set default 'INR';
alter table public.cart_items alter column currency set default 'INR';
alter table public.orders alter column currency set default 'INR';
alter table public.order_items alter column currency set default 'INR';

update public.products set currency = 'INR' where currency = 'USD';
update public.cart_items set currency = 'INR' where currency = 'USD';
update public.orders set currency = 'INR' where currency = 'USD';
update public.order_items set currency = 'INR' where currency = 'USD';

-- Future variant support (safe for existing databases).
alter table public.products add column if not exists size text;
alter table public.products add column if not exists color text;
alter table public.products add column if not exists weight numeric(10,3);
alter table public.products add column if not exists sku text;
alter table public.products add column if not exists brand text;
alter table public.products add column if not exists tags text[] not null default '{}';
alter table public.products add column if not exists dimensions text;

-- Customer profile details for user/admin customer pages.
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists address text;
