-- Allow authenticated user to safely rebind current device FCM token to self.
-- This avoids stale token ownership causing cross-account push delivery.

create or replace function public.register_my_device_token(
  p_fcm_token text,
  p_device_type text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := nullif(trim(coalesce(p_fcm_token, '')), '');
  v_device_type text := coalesce(nullif(trim(coalesce(p_device_type, '')), ''), 'android');
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if v_token is null then
    raise exception 'invalid_fcm_token';
  end if;

  -- Keep latest pointer for per-user push fallback.
  update public.profiles
  set
    fcm_token = v_token,
    updated_at = now()
  where id = v_uid;

  -- Remove stale ownership of this token, if any.
  delete from public.user_devices where fcm_token = v_token;

  insert into public.user_devices (user_id, fcm_token, device_type)
  values (v_uid, v_token, v_device_type)
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        device_type = excluded.device_type;
end;
$$;

revoke all on function public.register_my_device_token(text, text) from public;
grant execute on function public.register_my_device_token(text, text) to authenticated;

