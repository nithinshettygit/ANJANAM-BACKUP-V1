-- Rich storefront autocomplete: title (prefix + contains), category, description, tags — one row per product, ranked.

create or replace function public.storefront_search_suggestions(
  p_query text,
  p_limit int default 12
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_raw text := left(trim(both from coalesce(p_query, '')), 80);
  v_esc text;
  v_like text;
  n int := greatest(1, least(coalesce(nullif(p_limit, 0), 12), 24));
begin
  if char_length(v_raw) < 2 then
    return '[]'::jsonb;
  end if;

  v_esc := replace(replace(replace(v_raw, e'\\', e'\\\\'), '%', e'\\%'), '_', e'\\_');
  v_like := '%' || v_esc || '%';

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'title', s.title,
          'category', s.category,
          'match_kind', s.match_kind
        )
        order by s.sort_pri asc, s.title asc
      )
      from (
        select
          p.id,
          p.title,
          p.category,
          case
            when p.title ilike v_esc || '%' escape e'\\' then 'title_prefix'
            when p.title ilike v_like escape e'\\' then 'title'
            when p.category is not null and btrim(p.category) <> '' and p.category ilike v_like escape e'\\' then 'category'
            when coalesce(p.description, '') ilike v_like escape e'\\' then 'description'
            when exists (
              select 1
              from unnest(coalesce(p.tags, '{}'::text[])) as t(tag)
              where tag ilike v_like escape e'\\'
            ) then 'tag'
            else 'title'
          end as match_kind,
          case
            when p.title ilike v_esc || '%' escape e'\\' then 0
            when p.title ilike v_like escape e'\\' then 1
            when p.category is not null and btrim(p.category) <> '' and p.category ilike v_like escape e'\\' then 2
            when coalesce(p.description, '') ilike v_like escape e'\\' then 3
            else 4
          end as sort_pri
        from public.products p
        where coalesce(p.is_active, true)
          and (
            p.title ilike v_like escape e'\\'
            or coalesce(p.description, '') ilike v_like escape e'\\'
            or (p.category is not null and btrim(p.category) <> '' and p.category ilike v_like escape e'\\')
            or exists (
              select 1
              from unnest(coalesce(p.tags, '{}'::text[])) as t2(tag)
              where tag ilike v_like escape e'\\'
            )
          )
        order by sort_pri asc, p.title asc
        limit n
      ) s
    ),
    '[]'::jsonb
  );
end;
$$;

revoke all on function public.storefront_search_suggestions(text, int) from public;
grant execute on function public.storefront_search_suggestions(text, int) to anon, authenticated;
