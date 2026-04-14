-- Allow Google auth login type alongside existing email/phone login methods.

alter table public.profiles
  drop constraint if exists profiles_login_type_check;

alter table public.profiles
  add constraint profiles_login_type_check
  check (login_type is null or login_type in ('email', 'phone', 'google'));
