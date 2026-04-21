-- Webhook processing state + function execute hardening.

alter table public.webhook_events
  add column if not exists status text not null default 'processing'
    check (status in ('processing', 'succeeded', 'failed')),
  add column if not exists last_error text,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_webhook_events_status_created
  on public.webhook_events (status, created_at desc);

revoke all on function public.create_admin_notification(text, text, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.create_admin_notification(text, text, text, uuid, text)
  to service_role;
