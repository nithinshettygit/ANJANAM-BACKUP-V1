create table if not exists public.explore_suggestions (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('article', 'video')),
  article_id uuid references public.articles(id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  title_override text,
  subtitle_override text,
  image_url text,
  badge_label text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint explore_suggestions_target_consistency check (
    (content_type = 'article' and article_id is not null and video_id is null) or
    (content_type = 'video' and video_id is not null and article_id is null)
  )
);

create index if not exists explore_suggestions_active_sort_idx
  on public.explore_suggestions (is_active, sort_order, created_at desc);

drop trigger if exists trg_explore_suggestions_updated_at on public.explore_suggestions;
create trigger trg_explore_suggestions_updated_at
before update on public.explore_suggestions
for each row execute function public.set_updated_at();

alter table public.explore_suggestions enable row level security;
alter table public.explore_suggestions force row level security;

drop policy if exists "explore_suggestions_select_public_active" on public.explore_suggestions;
create policy "explore_suggestions_select_public_active"
on public.explore_suggestions
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "explore_suggestions_select_admin" on public.explore_suggestions;
create policy "explore_suggestions_select_admin"
on public.explore_suggestions
for select
to authenticated
using (public.is_admin());

drop policy if exists "explore_suggestions_insert_admin" on public.explore_suggestions;
create policy "explore_suggestions_insert_admin"
on public.explore_suggestions
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "explore_suggestions_update_admin" on public.explore_suggestions;
create policy "explore_suggestions_update_admin"
on public.explore_suggestions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "explore_suggestions_delete_admin" on public.explore_suggestions;
create policy "explore_suggestions_delete_admin"
on public.explore_suggestions
for delete
to authenticated
using (public.is_admin());

grant select on public.explore_suggestions to anon, authenticated;
grant insert, update, delete on public.explore_suggestions to authenticated;
