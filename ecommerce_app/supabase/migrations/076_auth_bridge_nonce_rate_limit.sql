-- Hardening for auth bridge flows:
-- - one-time client nonce replay protection
-- - basic server-side rate limiting ledger (service-role only)

create table if not exists public.auth_bridge_nonces (
  id uuid primary key default gen_random_uuid(),
  bridge_type text not null check (bridge_type in ('google', 'phone')),
  firebase_uid text not null,
  nonce_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz
);

create index if not exists idx_auth_bridge_nonces_uid_created
  on public.auth_bridge_nonces (bridge_type, firebase_uid, created_at desc);

create table if not exists public.auth_bridge_rate_limits (
  key text primary key,
  window_started_at timestamptz not null,
  attempt_count integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.auth_bridge_nonces enable row level security;
alter table public.auth_bridge_nonces force row level security;
drop policy if exists "auth_bridge_nonces_service_role_all" on public.auth_bridge_nonces;
create policy "auth_bridge_nonces_service_role_all"
on public.auth_bridge_nonces
for all
to service_role
using (true)
with check (true);

alter table public.auth_bridge_rate_limits enable row level security;
alter table public.auth_bridge_rate_limits force row level security;
drop policy if exists "auth_bridge_rate_limits_service_role_all" on public.auth_bridge_rate_limits;
create policy "auth_bridge_rate_limits_service_role_all"
on public.auth_bridge_rate_limits
for all
to service_role
using (true)
with check (true);
