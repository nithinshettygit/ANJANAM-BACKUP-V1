-- Critical Security Advisor hardening (safe, minimal scope):
-- 1) Ensure replacement stuck-cases view uses invoker permissions.
-- 2) Remove anonymous/public execute on admin SECURITY DEFINER functions.
--
-- Notes:
-- - We intentionally keep existing authenticated grants unchanged.
-- - This avoids breaking admin app behavior while closing critical public exposure.

begin;

-- ---------------------------------------------------------------------------
-- View hardening: avoid SECURITY DEFINER behavior on this diagnostic view.
-- ---------------------------------------------------------------------------
alter view if exists public.v_replacement_cases_stuck
  set (security_invoker = true);

-- ---------------------------------------------------------------------------
-- Function hardening: revoke execute from anon/public for admin definer RPCs.
-- We target only public schema SECURITY DEFINER functions whose names are:
--   - admin_*
--   - is_admin / is_active_admin / is_super_admin
-- ---------------------------------------------------------------------------
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
      and (
        p.proname like 'admin\_%' escape '\'
        or p.proname in ('is_admin', 'is_active_admin', 'is_super_admin')
      )
  loop
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

