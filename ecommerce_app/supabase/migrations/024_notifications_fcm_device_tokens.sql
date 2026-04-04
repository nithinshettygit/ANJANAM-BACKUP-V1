-- ---------------------------------------------------------------------------
-- FCM device tokens + notification redirect metadata
-- ---------------------------------------------------------------------------

-- Device token registry (1 user may have multiple devices/tokens).
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text not null,
  device_type text not null default 'android',
  created_at timestamptz not null default now()
);

-- Prevent duplicate tokens per user/device.
create unique index if not exists idx_user_devices_unique_user_token
  on public.user_devices (user_id, fcm_token);

-- Extra global uniqueness helps avoid sending to stale duplicates.
create unique index if not exists idx_user_devices_unique_token
  on public.user_devices (fcm_token);

alter table public.user_devices enable row level security;
alter table public.user_devices force row level security;

drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own"
on public.user_devices
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "user_devices_insert_own" on public.user_devices;
create policy "user_devices_insert_own"
on public.user_devices
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "user_devices_update_own" on public.user_devices;
create policy "user_devices_update_own"
on public.user_devices
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Add redirect metadata expected by the app's notification redirects.
-- Keep defaults NULL so existing triggers keep working.
-- ---------------------------------------------------------------------------
alter table public.user_notifications
  add column if not exists redirect_type text,
  add column if not exists redirect_value text;

create index if not exists idx_user_notifications_order_id_created
  on public.user_notifications (order_id, created_at desc);

-- Allow authenticated users to insert their own in-app notification history
-- (needed for "Order placed" history, since DB triggers currently cover
-- only later status transitions).
drop policy if exists "user_notifications_insert_own" on public.user_notifications;
create policy "user_notifications_insert_own"
on public.user_notifications
for insert
to authenticated
with check (user_id = auth.uid());

