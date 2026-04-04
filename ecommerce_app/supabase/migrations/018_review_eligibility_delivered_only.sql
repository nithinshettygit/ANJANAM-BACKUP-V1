-- Reviews: strict eligibility = at least one order line for the product in a **delivered**
-- terminal state (case-insensitive). Legacy `completed` rows count the same as delivered.

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
    and lower(trim(both from o.status)) in ('delivered', 'completed')
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
      and lower(trim(both from o.status)) in ('delivered', 'completed')
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
