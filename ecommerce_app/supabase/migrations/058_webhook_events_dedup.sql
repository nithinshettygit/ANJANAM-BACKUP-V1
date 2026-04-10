-- Razorpay webhook deduplication ledger.

create table if not exists public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  event_type text,
  created_at timestamptz not null default now(),
  payload jsonb
);

create index if not exists idx_webhook_events_created_at
  on public.webhook_events (created_at desc);
