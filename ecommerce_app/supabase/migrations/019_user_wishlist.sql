-- Per-user product wishlist (survives app restarts when signed in).
-- Guests use client-side SharedPreferences until they sign in (then rows merge here).

create table if not exists public.wishlist_items (
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists idx_wishlist_items_user_id on public.wishlist_items (user_id);
create index if not exists idx_wishlist_items_product_id on public.wishlist_items (product_id);

alter table public.wishlist_items enable row level security;
alter table public.wishlist_items force row level security;

drop policy if exists "wishlist_items_select_own" on public.wishlist_items;
create policy "wishlist_items_select_own"
on public.wishlist_items
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "wishlist_items_insert_own" on public.wishlist_items;
create policy "wishlist_items_insert_own"
on public.wishlist_items
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "wishlist_items_delete_own" on public.wishlist_items;
create policy "wishlist_items_delete_own"
on public.wishlist_items
for delete
to authenticated
using (auth.uid() = user_id);
