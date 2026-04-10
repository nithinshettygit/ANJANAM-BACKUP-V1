-- Enforce admin-account blocking guard at DB level.
-- Rule:
-- - super_admin accounts cannot be blocked/unblocked by anyone except service role ops
-- - admin accounts can be blocked/unblocked only by super_admin
-- - regular admins can block/unblock only customer accounts

create or replace function public.enforce_profile_blocking_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_claim_role text := lower(coalesce(current_setting('request.jwt.claim.role', true), ''));
  v_target_role text := lower(coalesce(new.role, old.role, 'customer'));
  v_blocking_change boolean :=
    new.status is distinct from old.status
    or new.blocked_reason is distinct from old.blocked_reason
    or new.blocked_at is distinct from old.blocked_at;
begin
  if not v_blocking_change then
    return new;
  end if;

  -- Allow trusted service role maintenance jobs/webhooks.
  if v_claim_role = 'service_role' then
    return new;
  end if;

  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not public.is_admin(v_uid) then
    raise exception 'not_authorized';
  end if;

  -- Nobody should block/unblock super_admin from regular app sessions.
  if v_target_role = 'super_admin' then
    raise exception 'super_admin_accounts_cannot_be_blocked';
  end if;

  -- Only super_admin can manage admin account block state.
  if v_target_role = 'admin' and not public.is_super_admin(v_uid) then
    raise exception 'only_super_admin_can_manage_admin_blocking';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_enforce_blocking_permissions on public.profiles;
create trigger trg_profiles_enforce_blocking_permissions
before update on public.profiles
for each row
execute function public.enforce_profile_blocking_permissions();
