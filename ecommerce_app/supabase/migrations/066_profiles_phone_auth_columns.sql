-- Add phone-auth linkage fields to existing public.profiles model.
-- Keep compatibility with existing email auth + profile usage.

alter table public.profiles
  add column if not exists phone text,
  add column if not exists firebase_uid text,
  add column if not exists login_type text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_login_type_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_login_type_check
      check (login_type is null or login_type in ('email', 'phone'));
  end if;
end
$$;

-- Backfill existing rows conservatively as email login type.
update public.profiles
set login_type = 'email'
where login_type is null
  and coalesce(trim(email), '') <> '';

create unique index if not exists idx_profiles_phone_unique
  on public.profiles (lower(trim(phone)))
  where phone is not null and trim(phone) <> '';

create unique index if not exists idx_profiles_firebase_uid_unique
  on public.profiles (firebase_uid)
  where firebase_uid is not null and trim(firebase_uid) <> '';
