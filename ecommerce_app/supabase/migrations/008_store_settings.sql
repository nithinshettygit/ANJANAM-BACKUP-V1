-- Store-wide storefront display settings (readable by anon for product cards).
create table if not exists public.store_settings (
  id smallint primary key default 1 check (id = 1),
  display_discount_percent integer not null default 17
    check (display_discount_percent >= 0 and display_discount_percent <= 99),
  updated_at timestamptz not null default now()
);

insert into public.store_settings (id, display_discount_percent)
values (1, 17)
on conflict (id) do nothing;

drop trigger if exists trg_store_settings_updated_at on public.store_settings;
create trigger trg_store_settings_updated_at
before update on public.store_settings
for each row execute function public.set_updated_at();

alter table public.store_settings enable row level security;
alter table public.store_settings force row level security;

drop policy if exists "store_settings_select_public" on public.store_settings;
create policy "store_settings_select_public"
on public.store_settings
for select
to anon, authenticated
using (true);

drop policy if exists "store_settings_insert_admin" on public.store_settings;
create policy "store_settings_insert_admin"
on public.store_settings
for insert
to authenticated
with check (public.is_admin() and id = 1);

drop policy if exists "store_settings_update_admin" on public.store_settings;
create policy "store_settings_update_admin"
on public.store_settings
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
