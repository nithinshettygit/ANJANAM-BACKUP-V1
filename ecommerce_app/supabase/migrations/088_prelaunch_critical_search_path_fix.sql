-- Pre-launch critical hardening:
-- Resolve remaining "Function Search Path Mutable" warnings for known functions.
-- This is low-risk and does not change business logic.

begin;

do $$
declare
  fn_name text;
  fn_sig text;
begin
  for fn_name in
    select unnest(array[
      'trg_reviews_refresh_product_stats',
      'set_updated_at',
      'returns_valid_status_transition',
      'orders_valid_status_transition'
    ])
  loop
    for fn_sig in
      select pg_catalog.pg_get_function_identity_arguments(p.oid)
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = fn_name
    loop
      execute format(
        'alter function public.%I(%s) set search_path = public, pg_temp',
        fn_name,
        fn_sig
      );
    end loop;
  end loop;
end
$$;

commit;

