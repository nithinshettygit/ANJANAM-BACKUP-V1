-- Human-readable audit lines for admin activity (e.g. "Admin updated product price: …").
alter table public.admin_logs add column if not exists message text;
