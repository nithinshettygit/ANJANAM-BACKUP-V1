-- Align admin authorization with active-status enforcement.
-- This keeps legacy callers of is_admin()/is_super_admin() working while
-- ensuring blocked admins are denied everywhere those helpers are used.

create or replace function public.is_active_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = uid
      and lower(coalesce(p.role, 'customer')) in ('admin', 'super_admin')
      and lower(coalesce(p.status, 'active')) = 'active'
  );
$$;

create or replace function public.is_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_active_admin(uid);
$$;

create or replace function public.is_super_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = uid
      and lower(coalesce(p.role, 'customer')) = 'super_admin'
      and lower(coalesce(p.status, 'active')) = 'active'
  );
$$;

revoke all on function public.is_active_admin(uuid) from public;
grant execute on function public.is_active_admin(uuid) to authenticated;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;

revoke all on function public.is_super_admin(uuid) from public;
grant execute on function public.is_super_admin(uuid) to authenticated;
