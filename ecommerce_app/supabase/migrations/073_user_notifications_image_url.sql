-- Optional media for customer-facing notifications.
-- Supports rich push (image) and in-app full-screen notification rendering.

alter table public.user_notifications
  add column if not exists image_url text;

