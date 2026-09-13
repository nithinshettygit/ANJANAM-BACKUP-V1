-- Explicit original/invoice address snapshot names for the shipping-address contract.
-- Existing shipping_* and invoice_* columns remain for backward compatibility.
alter table public.orders
  add column if not exists shipping_name_original text,
  add column if not exists shipping_address_original text,
  add column if not exists shipping_city_original text,
  add column if not exists shipping_state_original text,
  add column if not exists shipping_name_invoice text,
  add column if not exists shipping_address_invoice text,
  add column if not exists shipping_city_invoice text,
  add column if not exists shipping_state_invoice text;

update public.orders
set
  shipping_name_original = coalesce(shipping_name_original, shipping_full_name),
  shipping_address_original = coalesce(shipping_address_original, shipping_address_line),
  shipping_city_original = coalesce(shipping_city_original, shipping_city),
  shipping_state_original = coalesce(shipping_state_original, shipping_state),
  shipping_name_invoice = coalesce(shipping_name_invoice, invoice_name),
  shipping_address_invoice = coalesce(shipping_address_invoice, invoice_address_line),
  shipping_city_invoice = coalesce(shipping_city_invoice, invoice_city),
  shipping_state_invoice = coalesce(shipping_state_invoice, invoice_state)
where shipping_name_original is null
   or shipping_address_original is null
   or shipping_city_original is null
   or shipping_state_original is null
   or shipping_name_invoice is null
   or shipping_address_invoice is null
   or shipping_city_invoice is null
   or shipping_state_invoice is null;
