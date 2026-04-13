-- Ensure all delivery lifecycle sync fields exist on orders.

alter table public.orders
  add column if not exists shipment_status text,
  add column if not exists delivery_status text,
  add column if not exists delivered_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists last_tracking_update timestamptz;

create index if not exists idx_orders_shiprocket_status
  on public.orders (shipment_status)
  where shipment_status is not null;

create index if not exists idx_orders_last_tracking_update
  on public.orders (last_tracking_update desc)
  where last_tracking_update is not null;
