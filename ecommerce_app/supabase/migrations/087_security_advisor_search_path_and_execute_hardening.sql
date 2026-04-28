-- Security Advisor hardening pass (low-risk):
-- 1) Lock search_path on SECURITY DEFINER functions in public schema.
-- 2) Revoke EXECUTE from anon/public for all such functions.
--
-- Why safe:
-- - Existing authenticated/service_role grants remain unchanged.
-- - Function bodies continue to work; only runtime lookup path is fixed.

begin;

do $$
declare
  r record;
begin
  for r in
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_catalog.pg_get_function_identity_arguments(p.oid) as identity_args
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef = true
  loop
    -- Fix "Function Search Path Mutable" warning.
    execute format(
      'alter function %I.%I(%s) set search_path = public, pg_temp',
      r.schema_name, r.function_name, r.identity_args
    );

    -- Prevent anonymous/public direct execution by default.
    execute format(
      'revoke execute on function %I.%I(%s) from public',
      r.schema_name, r.function_name, r.identity_args
    );
    execute format(
      'revoke execute on function %I.%I(%s) from anon',
      r.schema_name, r.function_name, r.identity_args
    );
  end loop;
end
$$;

commit;

