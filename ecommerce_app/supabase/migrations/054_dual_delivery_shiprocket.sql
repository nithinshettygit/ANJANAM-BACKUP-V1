-- Dual delivery: manual vs Shiprocket. New columns on orders; optional shipping_state for courier APIs.

alter table public.orders
  add column if not exists shipping_state text,
  add column if not exists delivery_method text,
  add column if not exists delivery_status text,
  add column if not exists delivery_partner_name text,
  add column if not exists delivery_partner_phone text,
  add column if not exists shipping_provider text,
  add column if not exists shipment_id text,
  add column if not exists awb_code text,
  add column if not exists tracking_url text,
  add column if not exists shipment_status text,
  add column if not exists shipped_at timestamptz;

comment on column public.orders.delivery_method is
  'manual_delivery | shiprocket_delivery | null (unset).';
comment on column public.orders.delivery_status is
  'Manual flow: pending | assigned | packed | out_for_delivery | delivered | failed.';
comment on column public.orders.shipment_status is
  'Shiprocket flow: shipment_created | pickup_scheduled | in_transit | out_for_delivery | delivered | failed.';
comment on column public.orders.shipment_id is
  'Shiprocket shipment id (stringified); duplicate creation blocked when set.';

create index if not exists idx_orders_delivery_method on public.orders (delivery_method)
  where delivery_method is not null;

create index if not exists idx_orders_shipment_id on public.orders (shipment_id)
  where shipment_id is not null;
