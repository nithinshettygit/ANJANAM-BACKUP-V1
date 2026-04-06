-- Articles marketplace module.
create extension if not exists pgcrypto;

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  author_name text not null,
  author_bio text not null default '',
  author_photo_url text,
  cover_image_url text,
  pdf_url text not null,
  category text,
  is_free boolean not null default false,
  price numeric(12,2) not null default 0 check (price >= 0),
  is_published boolean not null default false,
  is_featured boolean not null default false,
  is_trending boolean not null default false,
  checkout_product_id uuid references public.products(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint articles_pricing_consistency check (
    (is_free = true and price = 0) or
    (is_free = false and price > 0)
  )
);

create index if not exists articles_published_created_idx
  on public.articles (is_published, created_at desc);
create index if not exists articles_category_idx
  on public.articles (category);
create index if not exists articles_checkout_product_idx
  on public.articles (checkout_product_id);

drop trigger if exists trg_articles_updated_at on public.articles;
create trigger trg_articles_updated_at
before update on public.articles
for each row execute function public.set_updated_at();

create table if not exists public.article_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  purchased_at timestamptz not null default now(),
  unique (user_id, article_id)
);

create index if not exists article_purchases_user_purchased_idx
  on public.article_purchases (user_id, purchased_at desc);
create index if not exists article_purchases_article_idx
  on public.article_purchases (article_id);

alter table public.articles enable row level security;
alter table public.articles force row level security;

drop policy if exists "articles_select_published_public" on public.articles;
create policy "articles_select_published_public"
on public.articles
for select
to anon, authenticated
using (is_published = true);

drop policy if exists "articles_select_admin" on public.articles;
create policy "articles_select_admin"
on public.articles
for select
to authenticated
using (public.is_admin());

drop policy if exists "articles_insert_admin" on public.articles;
create policy "articles_insert_admin"
on public.articles
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "articles_update_admin" on public.articles;
create policy "articles_update_admin"
on public.articles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "articles_delete_admin" on public.articles;
create policy "articles_delete_admin"
on public.articles
for delete
to authenticated
using (public.is_admin());

grant select on public.articles to anon, authenticated;
grant insert, update, delete on public.articles to authenticated;

alter table public.article_purchases enable row level security;
alter table public.article_purchases force row level security;

drop policy if exists "article_purchases_select_own" on public.article_purchases;
create policy "article_purchases_select_own"
on public.article_purchases
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "article_purchases_insert_own_or_admin" on public.article_purchases;
create policy "article_purchases_insert_own_or_admin"
on public.article_purchases
for insert
to authenticated
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "article_purchases_delete_admin" on public.article_purchases;
create policy "article_purchases_delete_admin"
on public.article_purchases
for delete
to authenticated
using (public.is_admin());

grant select, insert on public.article_purchases to authenticated;
grant delete on public.article_purchases to authenticated;

create or replace function public.ensure_article_checkout_product(p_article_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_article public.articles%rowtype;
  v_product_id uuid;
begin
  if not public.is_admin() then
    raise exception 'admin_only';
  end if;

  select * into v_article
  from public.articles
  where id = p_article_id;

  if v_article.id is null then
    raise exception 'article_not_found';
  end if;

  if v_article.is_free then
    return null;
  end if;

  if v_article.checkout_product_id is not null then
    update public.products
      set title = v_article.title,
          description = v_article.description,
          price = v_article.price,
          category = coalesce(v_article.category, 'articles'),
          is_active = v_article.is_published
    where id = v_article.checkout_product_id;
    return v_article.checkout_product_id;
  end if;

  insert into public.products (
    title, description, category, sku, brand, tags, price, currency,
    weight, dimensions, inventory_count, image_urls, is_active
  )
  values (
    v_article.title,
    v_article.description,
    coalesce(v_article.category, 'articles'),
    concat('ART-', substring(replace(v_article.id::text, '-', '') from 1 for 12)),
    'ANJANAM Articles',
    array['article', 'premium'],
    v_article.price,
    'INR',
    0,
    '',
    999999,
    case
      when v_article.cover_image_url is not null and btrim(v_article.cover_image_url) <> ''
      then array[v_article.cover_image_url]
      else array[]::text[]
    end,
    v_article.is_published
  )
  returning id into v_product_id;

  update public.articles
  set checkout_product_id = v_product_id
  where id = v_article.id;

  return v_product_id;
end;
$$;

revoke all on function public.ensure_article_checkout_product(uuid) from public;
grant execute on function public.ensure_article_checkout_product(uuid) to authenticated;

-- Storage: private PDF + public images in `articles` bucket.
insert into storage.buckets (id, name, public)
values ('articles', 'articles', false)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "articles_storage_read_pdf_owner_or_admin" on storage.objects;
create policy "articles_storage_read_pdf_owner_or_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'articles'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.articles a
      where a.pdf_url = name
        and a.is_published = true
        and (a.is_free = true or exists (
          select 1
          from public.article_purchases ap
          where ap.article_id = a.id
            and ap.user_id = auth.uid()
        ))
    )
  )
);

drop policy if exists "articles_storage_read_images_public" on storage.objects;
create policy "articles_storage_read_images_public"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'articles'
  and (
    name like 'covers/%'
    or name like 'authors/%'
  )
);

drop policy if exists "articles_storage_admin_write" on storage.objects;
create policy "articles_storage_admin_write"
on storage.objects
for all
to authenticated
using (bucket_id = 'articles' and public.is_admin())
with check (bucket_id = 'articles' and public.is_admin());
