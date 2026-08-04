-- SEC2: get_own_account_restriction must not accept arbitrary UUIDs.
-- Always resolve against auth.uid(); ignore client-supplied uid parameter.

create or replace function public.get_own_account_restriction(uid uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  -- Intentionally ignore [uid] argument to prevent cross-user probing.
  select jsonb_build_object(
    'restricted', lower(coalesce(p.status, 'active')) = 'blocked',
    'error_code',
      case
        when lower(coalesce(p.status, 'active')) <> 'blocked' then null
        when lower(coalesce(p.role, 'customer')) in ('admin', 'super_admin') then 'ADMIN_BLOCKED'
        else 'USER_BLOCKED'
      end,
    'message',
      case
        when lower(coalesce(p.status, 'active')) <> 'blocked' then null
        when nullif(btrim(coalesce(p.blocked_reason, '')), '') is not null
          then btrim(p.blocked_reason)
        when lower(coalesce(p.role, 'customer')) in ('admin', 'super_admin')
          then 'Admin account is blocked.'
        else 'User is blocked by admin'
      end,
    'blocked_reason', p.blocked_reason,
    'role', p.role
  )
  into v_row
  from public.profiles p
  where p.id = v_uid;

  return coalesce(v_row, jsonb_build_object('restricted', false));
end;
$$;

revoke all on function public.get_own_account_restriction(uuid) from public;
grant execute on function public.get_own_account_restriction(uuid) to authenticated;

comment on function public.get_own_account_restriction(uuid) is
  'Returns restriction metadata for auth.uid() only (ignores uid arg; blocked users can still call when profiles RLS denies reads).';
