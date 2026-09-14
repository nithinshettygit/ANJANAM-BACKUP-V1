-- Allow customers to edit their own profile name.
-- Google sign-in preservation is handled by google-auth-bridge, not a database trigger.
drop trigger if exists trg_preserve_google_profile_name on public.profiles;
drop function if exists public.preserve_google_profile_name();
