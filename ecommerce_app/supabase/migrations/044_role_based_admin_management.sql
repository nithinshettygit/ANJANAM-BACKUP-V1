-- Role-based admin management: customer/admin/super_admin.
-- Safe migration from legacy role values (user/admin).

alter table public.profiles
  add column if not exists role text;

update public.profiles
set role = case
  when lower(coalesce(role, '')) = 'admin' then 'admin'
  when lower(coalesce(role, '')) = 'super_admin' then 'super_admin'
  else 'customer'
end
where role is null
   or btrim(role) = ''
   or lower(role) in ('user', 'admin', 'super_admin')
   or lower(role) not in ('customer', 'admin', 'super_admin');

alter table public.profiles
  alter column role set default 'customer';

alter table public.profiles
  alter column role set not null;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('customer', 'admin', 'super_admin'));

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
  );
$$;

create or replace function public.is_admin(uid uuid default auth.uid())
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
  );
$$;

grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_super_admin(uuid) to authenticated;

-- Only super admins can change role assignments.
create or replace function public.enforce_profile_role_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if lower(coalesce(new.role, 'customer')) not in ('customer', 'admin', 'super_admin') then
    raise exception 'invalid_role';
  end if;

  if new.role is distinct from old.role then
    if v_uid is null then
      raise exception 'not_authenticated';
    end if;
    if not public.is_super_admin(v_uid) then
      raise exception 'only_super_admin_can_change_roles';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_enforce_role_update on public.profiles;
create trigger trg_profiles_enforce_role_update
before update on public.profiles
for each row execute function public.enforce_profile_role_update();
