-- Security Advisor hardening:
-- 1) Enable + force RLS on internal webhook/error log tables.
-- 2) Keep access restricted to service_role (Edge Functions).
-- 3) Make storefront category view run as invoker to avoid SECURITY DEFINER warning.

begin;

-- ---------------------------------------------------------------------------
-- Internal log tables were intentionally created for backend diagnostics,
-- but must still have RLS enabled to satisfy security posture.
-- ---------------------------------------------------------------------------

alter table if exists public.system_error_logs enable row level security;
alter table if exists public.system_error_logs force row level security;

drop policy if exists "system_error_logs_service_role_all" on public.system_error_logs;
create policy "system_error_logs_service_role_all"
on public.system_error_logs
for all
to service_role
using (true)
with check (true);

alter table if exists public.webhook_events enable row level security;
alter table if exists public.webhook_events force row level security;

drop policy if exists "webhook_events_service_role_all" on public.webhook_events;
create policy "webhook_events_service_role_all"
on public.webhook_events
for all
to service_role
using (true)
with check (true);

alter table if exists public.shiprocket_webhook_logs enable row level security;
alter table if exists public.shiprocket_webhook_logs force row level security;

drop policy if exists "shiprocket_webhook_logs_service_role_all" on public.shiprocket_webhook_logs;
create policy "shiprocket_webhook_logs_service_role_all"
on public.shiprocket_webhook_logs
for all
to service_role
using (true)
with check (true);

-- ---------------------------------------------------------------------------
-- Ensure the storefront category cards view executes with invoker semantics.
-- This prevents bypass behavior and resolves Security Definer View advisor.
-- ---------------------------------------------------------------------------

alter view if exists public.v_shop_category_cards
  set (security_invoker = true);

commit;
