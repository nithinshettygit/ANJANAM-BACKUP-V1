-- Create a profile row whenever a new user is inserted into auth.users.
-- This avoids relying on the Flutter client to insert into public.profiles:
-- when "Confirm email" is enabled, signUp often returns no session, so the client
-- runs as anon and RLS ("to authenticated") blocks inserts — profile creation failed silently before.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name text;
begin
  v_full_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(split_part(coalesce(new.email, ''), '@', 1)), ''),
    'User'
  );

  insert into public.profiles (id, full_name, avatar_url, role, email)
  values (new.id, v_full_name, null, 'user', new.email)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
