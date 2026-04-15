-- Admin reply support for product reviews.
-- Adds seller reply fields and exposes them via list_product_reviews RPC.

alter table public.reviews
  add column if not exists admin_reply_text text,
  add column if not exists admin_reply_updated_at timestamptz;

alter table public.reviews
  drop constraint if exists reviews_admin_reply_text_len_check;

alter table public.reviews
  add constraint reviews_admin_reply_text_len_check
  check (
    admin_reply_text is null
    or length(trim(admin_reply_text)) <= 1000
  );

comment on column public.reviews.admin_reply_text is
  'Optional seller/admin reply shown under customer review on storefront.';
comment on column public.reviews.admin_reply_updated_at is
  'Last edit timestamp for seller/admin review reply.';

drop function if exists public.list_product_reviews(uuid, text, int, int);

create function public.list_product_reviews(
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
  author_display_name text,
  admin_reply_text text,
  admin_reply_updated_at timestamptz
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
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text,
      r.admin_reply_text,
      r.admin_reply_updated_at
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
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text,
      r.admin_reply_text,
      r.admin_reply_updated_at
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
      coalesce(nullif(trim(p.full_name::text), ''), 'Customer')::text,
      r.admin_reply_text,
      r.admin_reply_updated_at
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
