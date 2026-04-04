-- Product Q&A (storefront + admin). Storefront reads approved questions via SECURITY DEFINER RPC (author names).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.product_questions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  question text not null
    check (char_length(trim(question)) > 0 and char_length(question) <= 2000),
  created_at timestamptz not null default now(),
  is_approved boolean not null default true
);

create table if not exists public.product_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.product_questions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  answer text not null
    check (char_length(trim(answer)) > 0 and char_length(answer) <= 2000),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_questions_product_id_created
  on public.product_questions (product_id, created_at desc);

create index if not exists idx_product_questions_user_id
  on public.product_questions (user_id);

create index if not exists idx_product_answers_question_id_created
  on public.product_answers (question_id, created_at asc);

create index if not exists idx_product_answers_user_id
  on public.product_answers (user_id);

-- ---------------------------------------------------------------------------
-- Storefront: paginated fetch with nested answers + display names (no N+1 on client)
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
    select 1 from public.products p
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

revoke all on function public.fetch_product_questions_page(uuid, int, int) from public;
grant execute on function public.fetch_product_questions_page(uuid, int, int) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.product_questions enable row level security;
alter table public.product_questions force row level security;

alter table public.product_answers enable row level security;
alter table public.product_answers force row level security;

-- Questions: public read approved only
drop policy if exists "product_questions_select_public" on public.product_questions;
create policy "product_questions_select_public"
on public.product_questions
for select
to anon, authenticated
using (is_approved = true);

drop policy if exists "product_questions_select_admin" on public.product_questions;
create policy "product_questions_select_admin"
on public.product_questions
for select
to authenticated
using (public.is_admin());

-- Authenticated users insert their own questions (active products only)
drop policy if exists "product_questions_insert_authenticated" on public.product_questions;
create policy "product_questions_insert_authenticated"
on public.product_questions
for insert
to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.products p
    where p.id = product_id
      and coalesce(p.is_active, true) = true
  )
);

drop policy if exists "product_questions_update_admin" on public.product_questions;
create policy "product_questions_update_admin"
on public.product_questions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "product_questions_delete_admin" on public.product_questions;
create policy "product_questions_delete_admin"
on public.product_questions
for delete
to authenticated
using (public.is_admin());

-- Answers: read if parent question is approved (storefront)
drop policy if exists "product_answers_select_public" on public.product_answers;
create policy "product_answers_select_public"
on public.product_answers
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.product_questions q
    where q.id = question_id
      and q.is_approved = true
  )
);

drop policy if exists "product_answers_select_admin" on public.product_answers;
create policy "product_answers_select_admin"
on public.product_answers
for select
to authenticated
using (public.is_admin());

-- Only admins insert answers; row must be authored by current admin
drop policy if exists "product_answers_insert_admin" on public.product_answers;
create policy "product_answers_insert_admin"
on public.product_answers
for insert
to authenticated
with check (
  public.is_admin()
  and auth.uid() = user_id
);

drop policy if exists "product_answers_update_admin" on public.product_answers;
create policy "product_answers_update_admin"
on public.product_answers
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "product_answers_delete_admin" on public.product_answers;
create policy "product_answers_delete_admin"
on public.product_answers
for delete
to authenticated
using (public.is_admin());
