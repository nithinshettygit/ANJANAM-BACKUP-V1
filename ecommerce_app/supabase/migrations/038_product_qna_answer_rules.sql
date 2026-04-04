-- Product Q&A: verified buyers may answer; server-side RPC only for inserts; author or admin may update/delete.

-- ---------------------------------------------------------------------------
-- Column: verified-buyer answers (seller answers use is_admin = true)
-- ---------------------------------------------------------------------------
alter table public.product_answers
  add column if not exists is_verified_purchase boolean not null default false;

comment on column public.product_answers.is_verified_purchase is
  'True when answer was posted by a customer with a delivered/completed order for the question''s product.';

-- ---------------------------------------------------------------------------
-- Delivered order check (same idea as product reviews)
-- ---------------------------------------------------------------------------
create or replace function public.user_has_delivered_order_for_product(
  p_user_id uuid,
  p_product_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.user_id = p_user_id
      and oi.product_id = p_product_id
      and lower(trim(o.status)) in ('delivered', 'completed')
  );
$$;

revoke all on function public.user_has_delivered_order_for_product(uuid, uuid) from public;

-- ---------------------------------------------------------------------------
-- Storefront + app: who can answer on this product detail page
-- ---------------------------------------------------------------------------
create or replace function public.get_my_product_qna_answer_eligibility(p_product_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'is_admin', coalesce(public.is_admin(auth.uid()), false),
    'can_answer_as_verified_buyer',
      case
        when auth.uid() is null then false
        when coalesce(public.is_admin(auth.uid()), false) then false
        else public.user_has_delivered_order_for_product(auth.uid(), p_product_id)
      end
  );
$$;

revoke all on function public.get_my_product_qna_answer_eligibility(uuid) from public;
grant execute on function public.get_my_product_qna_answer_eligibility(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Single insert path: admin -> seller answer; verified buyer -> buyer answer
-- ---------------------------------------------------------------------------
create or replace function public.submit_product_answer(
  p_question_id uuid,
  p_answer text
)
returns public.product_answers
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_text text;
  v_product_id uuid;
  v_approved boolean;
  r public.product_answers%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  v_text := nullif(trim(coalesce(p_answer, '')), '');
  if v_text is null then
    raise exception 'answer_required';
  end if;
  if length(v_text) > 2000 then
    raise exception 'answer_too_long';
  end if;

  select pq.product_id, pq.is_approved
  into v_product_id, v_approved
  from public.product_questions pq
  where pq.id = p_question_id;

  if v_product_id is null then
    raise exception 'question_not_found';
  end if;

  if public.is_admin(v_uid) then
    insert into public.product_answers (
      question_id, user_id, answer, is_admin, is_verified_purchase
    )
    values (p_question_id, v_uid, v_text, true, false)
    returning * into r;
    return r;
  end if;

  if not coalesce(v_approved, false) then
    raise exception 'question_not_visible';
  end if;

  if not exists (
    select 1
    from public.products p
    where p.id = v_product_id
      and coalesce(p.is_active, true) = true
  ) then
    raise exception 'product_not_available';
  end if;

  if public.user_has_delivered_order_for_product(v_uid, v_product_id) then
    insert into public.product_answers (
      question_id, user_id, answer, is_admin, is_verified_purchase
    )
    values (p_question_id, v_uid, v_text, false, true)
    returning * into r;
    return r;
  end if;

  raise exception 'not_eligible_to_answer';
end;
$$;

revoke all on function public.submit_product_answer(uuid, text) from public;
grant execute on function public.submit_product_answer(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Public fetch: include is_verified_purchase for badges
-- ---------------------------------------------------------------------------
create or replace function public.fetch_product_questions_page(
  p_product_id uuid,
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_rows jsonb;
begin
  if not exists (
    select 1
    from public.products p
    where p.id = p_product_id and coalesce(p.is_active, true) = true
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.created_at desc), '[]'::jsonb)
  into v_rows
  from (
    select
      q.id,
      q.user_id,
      q.question,
      q.created_at,
      coalesce(nullif(trim(pr.full_name), ''), 'Customer') as author_display_name,
      coalesce(ans.answers_json, '[]'::jsonb) as answers
    from (
      select pq.*
      from public.product_questions pq
      where pq.product_id = p_product_id
        and pq.is_approved = true
      order by pq.created_at desc
      limit v_limit
      offset v_offset
    ) q
    join public.profiles pr on pr.id = q.user_id
    left join lateral (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', pa.id,
            'user_id', pa.user_id,
            'answer', pa.answer,
            'is_admin', pa.is_admin,
            'is_verified_purchase', pa.is_verified_purchase,
            'created_at', pa.created_at,
            'author_display_name', coalesce(nullif(trim(pans.full_name), ''), 'Customer')
          )
          order by pa.created_at asc
        ),
        '[]'::jsonb
      ) as answers_json
      from public.product_answers pa
      join public.profiles pans on pans.id = pa.user_id
      where pa.question_id = q.id
    ) ans on true
  ) t;

  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- Non-admins may only edit answer text (not flags / ownership)
-- ---------------------------------------------------------------------------
create or replace function public.trg_product_answers_author_edit_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null and public.is_admin(auth.uid()) then
    return new;
  end if;
  new.is_admin := old.is_admin;
  new.is_verified_purchase := old.is_verified_purchase;
  new.question_id := old.question_id;
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists trg_product_answers_author_edit_guard on public.product_answers;
create trigger trg_product_answers_author_edit_guard
before update on public.product_answers
for each row
execute function public.trg_product_answers_author_edit_guard();

-- ---------------------------------------------------------------------------
-- RLS: no direct inserts; authors or admins may update/delete
-- ---------------------------------------------------------------------------
drop policy if exists "product_answers_insert_admin" on public.product_answers;

drop policy if exists "product_answers_update_admin" on public.product_answers;
create policy "product_answers_update_own_or_admin"
on public.product_answers
for update
to authenticated
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "product_answers_delete_admin" on public.product_answers;
create policy "product_answers_delete_own_or_admin"
on public.product_answers
for delete
to authenticated
using (user_id = auth.uid() or public.is_admin());

-- Allow authors to read their own rows (e.g. after update) in addition to public/admin policies
drop policy if exists "product_answers_select_own" on public.product_answers;
create policy "product_answers_select_own"
on public.product_answers
for select
to authenticated
using (user_id = auth.uid());
