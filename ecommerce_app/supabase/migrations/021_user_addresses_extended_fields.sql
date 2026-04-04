-- Extend saved delivery addresses with optional line2/state/country fields.

alter table if exists public.user_addresses
  add column if not exists address_line2 text,
  add column if not exists state text,
  add column if not exists country text;
