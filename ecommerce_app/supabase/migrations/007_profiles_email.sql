-- Denormalized email on profiles so admin (and clients) can read it without auth.users access.
alter table public.profiles add column if not exists email text;

update public.profiles p
set email = au.email
from auth.users au
where p.id = au.id
  and au.email is not null
  and btrim(au.email) <> ''
  and (p.email is null or btrim(p.email) = '');
