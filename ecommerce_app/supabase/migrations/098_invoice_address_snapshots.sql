-- Preserve raw customer shipping data and add immutable invoice/label display snapshots.
-- Legacy orders remain valid and fall back to their existing shipping_* fields.
alter table public.orders
  add column if not exists invoice_name text,
  add column if not exists invoice_address_line text,
  add column if not exists invoice_city text,
  add column if not exists invoice_state text;

comment on column public.orders.invoice_name is
  'Latin-script display snapshot for invoices and shipping labels; original is shipping_full_name.';
comment on column public.orders.invoice_address_line is
  'Latin-script display snapshot for invoices and shipping labels; original is shipping_address_line.';
