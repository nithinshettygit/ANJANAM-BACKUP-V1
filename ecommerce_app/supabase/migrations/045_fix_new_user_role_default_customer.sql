-- Fix signup profile trigger after role model migration.
-- New users must default to role='customer' (not legacy 'user').

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
  values (new.id, v_full_name, null, 'customer', new.email)
  on conflict (id) do nothing;

  return new;
end;
$$;
