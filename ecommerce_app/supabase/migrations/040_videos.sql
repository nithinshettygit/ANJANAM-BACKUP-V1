-- Standalone storefront videos (YouTube URLs only; no binary video storage).

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  youtube_url text not null,
  thumbnail_url text,
  category text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists videos_created_at_desc_idx on public.videos (created_at desc);
create index if not exists videos_active_created_at_desc_idx on public.videos (is_active, created_at desc);

alter table public.videos enable row level security;
alter table public.videos force row level security;

-- Anyone with anon or authenticated: read rows that are active.
drop policy if exists "videos_select_active_public" on public.videos;
create policy "videos_select_active_public"
on public.videos
for select
to anon, authenticated
using (is_active = true);

-- Admins: read all rows (inactive included).
drop policy if exists "videos_select_admin" on public.videos;
create policy "videos_select_admin"
on public.videos
for select
to authenticated
using (public.is_admin());

drop policy if exists "videos_insert_admin" on public.videos;
create policy "videos_insert_admin"
on public.videos
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "videos_update_admin" on public.videos;
create policy "videos_update_admin"
on public.videos
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "videos_delete_admin" on public.videos;
create policy "videos_delete_admin"
on public.videos
for delete
to authenticated
using (public.is_admin());

grant select on public.videos to anon, authenticated;
grant insert, update, delete on public.videos to authenticated;
