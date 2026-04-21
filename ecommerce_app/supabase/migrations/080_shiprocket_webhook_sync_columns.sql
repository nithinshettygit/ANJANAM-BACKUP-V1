-- Shiprocket sync support fields on orders.

alter table public.orders
  add column if not exists cancelled_at timestamptz,
  add column if not exists last_tracking_update timestamptz;

create index if not exists idx_orders_last_tracking_update
  on public.orders (last_tracking_update desc);

