-- Lets blocked users read their restriction status without profiles RLS (security definer).
-- Returns structured error_code for client UX (USER_BLOCKED / ADMIN_BLOCKED).

create or replace function public.get_own_account_restriction(uid uuid default auth.uid())
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
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
      from public.profiles p
      where p.id = uid
    ),
    jsonb_build_object('restricted', false)
  );
$$;

revoke all on function public.get_own_account_restriction(uuid) from public;
grant execute on function public.get_own_account_restriction(uuid) to authenticated;

comment on function public.get_own_account_restriction(uuid) is
  'Returns restriction metadata for the signed-in user (works when profiles RLS denies direct reads).';
