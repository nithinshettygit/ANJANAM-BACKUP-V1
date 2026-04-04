-- Product reviews & ratings (verified purchase, aggregates on products, moderation).

-- ---------------------------------------------------------------------------
-- Orders: allow COMPLETED as a terminal state for review eligibility
-- ---------------------------------------------------------------------------
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check check (
  status in (
    'PENDING','CONFIRMED','PROCESSING','SHIPPED','DELIVERED','COMPLETED',
    'CANCELLED','REFUNDED','AUTHORIZED','PAID','FAILED',
    -- Compatibility for lowercase statuses introduced by later migrations.
    'pending','confirmed','processing','shipped','delivered','completed',
    'cancelled','refunded','authorized','paid','failed',
    'placed'
  )
);

-- ---------------------------------------------------------------------------
-- Products: denormalized aggregates (visible reviews only)
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists average_rating numeric(3,2),
  add column if not exists total_reviews integer not null default 0,
  add column if not exists total_written_reviews integer not null default 0;

comment on column public.products.average_rating is 'AVG(rating) of visible reviews; NULL when none.';
comment on column public.products.total_reviews is 'Count of visible reviews (each has a rating).';
comment on column public.products.total_written_reviews is 'Visible reviews with non-empty review_text.';

-- ---------------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  order_id uuid references public.orders (id) on delete set null,
  rating integer not null check (rating >= 1 and rating <= 5),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_verified_purchase boolean not null default false,
  is_visible boolean not null default true,
  unique (user_id, product_id)
);

drop trigger if exists trg_reviews_updated_at on public.reviews;
create trigger trg_reviews_updated_at
before update on public.reviews
for each row execute function public.set_updated_at();

create index if not exists idx_reviews_product_visible_created
  on public.reviews (product_id, is_visible, created_at desc);

create index if not exists idx_reviews_user_id on public.reviews (user_id);

-- ---------------------------------------------------------------------------
-- Refresh product aggregates for one product (visible rows only)
-- ---------------------------------------------------------------------------
create or replace function public.refresh_product_review_stats(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3,2);
  v_cnt int;
  v_txt int;
begin
  select
    case when count(*) = 0 then null else round(avg(rating::numeric), 2) end,
    count(*)::int,
    count(*) filter (
      where nullif(trim(coalesce(review_text, '')), '') is not null
    )::int
  into v_avg, v_cnt, v_txt
  from public.reviews
  where product_id = p_product_id
    and is_visible = true;

  update public.products
  set
    average_rating = coalesce(v_avg, null),
    total_reviews = coalesce(v_cnt, 0),
    total_written_reviews = coalesce(v_txt, 0)
  where id = p_product_id;
end;
$$;

create or replace function public.trg_reviews_refresh_product_stats()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_product_review_stats(old.product_id);
  elsif tg_op = 'UPDATE' and old.product_id is distinct from new.product_id then
    perform public.refresh_product_review_stats(old.product_id);
    perform public.refresh_product_review_stats(new.product_id);
  else
    perform public.refresh_product_review_stats(coalesce(new.product_id, old.product_id));
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_reviews_refresh_stats on public.reviews;
create trigger trg_reviews_refresh_stats
after insert or update or delete on public.reviews
for each row execute function public.trg_reviews_refresh_product_stats();

-- ---------------------------------------------------------------------------
-- Submit or update own review (verified purchase enforced)
-- ---------------------------------------------------------------------------
create or replace function public.submit_product_review(
  p_product_id uuid,
  p_rating integer,
  p_review_text text
)
returns public.reviews
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
  v_text text;
  r public.reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating';
  end if;

  v_text := nullif(trim(coalesce(p_review_text, '')), '');
  if v_text is not null and length(v_text) > 1000 then
    raise exception 'review_text_too_long';
  end if;

  if not exists (
    select 1 from public.products p where p.id = p_product_id and p.is_active = true
  ) then
    raise exception 'product_not_found';
  end if;

  select o.id into v_order_id
  from public.orders o
  inner join public.order_items oi on oi.order_id = o.id
  where o.user_id = v_uid
    and oi.product_id = p_product_id
    and lower(o.status) in ('delivered', 'completed')
  order by o.created_at desc
  limit 1;

  if v_order_id is null then
    raise exception 'not_eligible';
  end if;

  insert into public.reviews (
    user_id,
    product_id,
    order_id,
    rating,
    review_text,
    is_verified_purchase,
    is_visible
  )
  values (
    v_uid,
    p_product_id,
    v_order_id,
    p_rating,
    v_text,
    true,
    true
  )
  on conflict (user_id, product_id) do update set
    rating = excluded.rating,
    review_text = excluded.review_text,
    order_id = excluded.order_id,
    is_verified_purchase = true,
    is_visible = true,
    updated_at = now()
  returning * into r;

  return r;
end;
$$;

revoke all on function public.submit_product_review(uuid, integer, text) from public;
grant execute on function public.submit_product_review(uuid, integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Eligibility + flags for UI (signed-in users)
-- ---------------------------------------------------------------------------
create or replace function public.get_my_review_eligibility(p_product_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_eligible boolean;
  v_has_review boolean;
begin
  if v_uid is null then
    return jsonb_build_object(
      'signed_in', false,
      'eligible', false,
      'has_review', false
    );
  end if;

  v_eligible := exists (
    select 1
    from public.orders o
    inner join public.order_items oi on oi.order_id = o.id
    where o.user_id = v_uid
      and oi.product_id = p_product_id
      and lower(o.status) in ('delivered', 'completed')
  );

  v_has_review := exists (
    select 1 from public.reviews
    where user_id = v_uid and product_id = p_product_id
  );

  return jsonb_build_object(
    'signed_in', true,
    'eligible', v_eligible,
    'has_review', v_has_review
  );
end;
$$;

revoke all on function public.get_my_review_eligibility(uuid) from public;
grant execute on function public.get_my_review_eligibility(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Rating distribution (1–5 counts) for visible reviews
-- ---------------------------------------------------------------------------
create or replace function public.get_product_rating_distribution(p_product_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(star::text, c),
    '{}'::jsonb
  )
  from (
    select rating as star, count(*)::int as c
    from public.reviews
    where product_id = p_product_id
      and is_visible = true
    group by rating
  ) s;
$$;

revoke all on function public.get_product_rating_distribution(uuid) from public;
grant execute on function public.get_product_rating_distribution(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Paginated review list (visible only; author name from profiles)
-- ---------------------------------------------------------------------------
create or replace function public.list_product_reviews(
  p_product_id uuid,
  p_sort text default 'recent',
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  id uuid,
  user_id uuid,
  rating integer,
  review_text text,
  created_at timestamptz,
  updated_at timestamptz,
  is_verified_purchase boolean,
  author_display_name text
)
language plpgsql
stable
security invoker
set search_path = public
as $$
begin
  p_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  if p_sort = 'high' then
    return query
    select
      r.id,
      r.user_id,
      r.rating,
      r.review_text,
      r.created_at,
      r.updated_at,
      r.is_verified_purchase,
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text
    from public.reviews r
    left join public.profiles p on p.id = r.user_id
    where r.product_id = p_product_id
      and r.is_visible = true
    order by r.rating desc, r.created_at desc
    limit p_limit offset p_offset;
  elsif p_sort = 'low' then
    return query
    select
      r.id,
      r.user_id,
      r.rating,
      r.review_text,
      r.created_at,
      r.updated_at,
      r.is_verified_purchase,
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text
    from public.reviews r
    left join public.profiles p on p.id = r.user_id
    where r.product_id = p_product_id
      and r.is_visible = true
    order by r.rating asc, r.created_at desc
    limit p_limit offset p_offset;
  else
    return query
    select
      r.id,
      r.user_id,
      r.rating,
      r.review_text,
      r.created_at,
      r.updated_at,
      r.is_verified_purchase,
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text
    from public.reviews r
    left join public.profiles p on p.id = r.user_id
    where r.product_id = p_product_id
      and r.is_visible = true
    order by r.created_at desc
    limit p_limit offset p_offset;
  end if;
end;
$$;

revoke all on function public.list_product_reviews(uuid, text, int, int) from public;
grant execute on function public.list_product_reviews(uuid, text, int, int) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.reviews enable row level security;
alter table public.reviews force row level security;

drop policy if exists "reviews_select_policy" on public.reviews;
create policy "reviews_select_policy"
on public.reviews
for select
to anon, authenticated
using (
  is_visible = true
  or user_id = (select auth.uid())
  or public.is_admin()
);

drop policy if exists "reviews_insert_none" on public.reviews;
-- No direct insert; use submit_product_review RPC.

drop policy if exists "reviews_update_admin" on public.reviews;
create policy "reviews_update_admin"
on public.reviews
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "reviews_delete_admin" on public.reviews;
create policy "reviews_delete_admin"
on public.reviews
for delete
to authenticated
using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Backfill aggregates (no rows yet — resets counters)
-- ---------------------------------------------------------------------------
update public.products p
set
  average_rating = null,
  total_reviews = 0,
  total_written_reviews = 0
where not exists (
  select 1 from public.reviews r where r.product_id = p.id and r.is_visible = true
);

-- Recompute for any existing review rows (if re-run)
do $$
declare
  r record;
begin
  for r in select distinct product_id from public.reviews
  loop
    perform public.refresh_product_review_stats(r.product_id);
  end loop;
end $$;
