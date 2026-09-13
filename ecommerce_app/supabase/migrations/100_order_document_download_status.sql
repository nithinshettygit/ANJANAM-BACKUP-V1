-- Track generated invoice and shipping-label downloads independently.
alter table public.orders
  add column if not exists invoice_downloaded_at timestamptz,
  add column if not exists label_downloaded_at timestamptz;

comment on column public.orders.invoice_downloaded_at is
  'Timestamp when an admin successfully downloaded an invoice for this order.';

comment on column public.orders.label_downloaded_at is
  'Timestamp when an admin successfully downloaded a shipping label for this order.';

create index if not exists idx_orders_invoice_downloaded_at
  on public.orders (invoice_downloaded_at);

create index if not exists idx_orders_label_downloaded_at
  on public.orders (label_downloaded_at);