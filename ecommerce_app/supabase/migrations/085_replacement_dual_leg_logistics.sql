-- Dual-leg replacement logistics: forward delivery + reverse pickup.

alter table public.replacement_cases
  add column if not exists logistics_mode text not null default 'manual'
    check (logistics_mode in ('manual', 'shiprocket', 'hybrid')),
  add column if not exists forward_shipment_id text,
  add column if not exists reverse_shipment_id text,
  add column if not exists forward_awb_code text,
  add column if not exists reverse_awb_code text,
  add column if not exists forward_tracking_url text,
  add column if not exists reverse_tracking_url text,
  add column if not exists forward_status text not null default 'pending'
    check (forward_status in (
      'pending',
      'created',
      'in_transit',
      'out_for_delivery',
      'delivered',
      'failed',
      'cancelled',
      'rto'
    )),
  add column if not exists reverse_status text not null default 'pending'
    check (reverse_status in (
      'pending',
      'scheduled',
      'in_transit',
      'out_for_pickup',
      'picked_up',
      'returned',
      'failed',
      'cancelled'
    ));

create unique index if not exists idx_replacement_cases_forward_shipment
  on public.replacement_cases(forward_shipment_id)
  where forward_shipment_id is not null and length(trim(forward_shipment_id)) > 0;

create unique index if not exists idx_replacement_cases_reverse_shipment
  on public.replacement_cases(reverse_shipment_id)
  where reverse_shipment_id is not null and length(trim(reverse_shipment_id)) > 0;

create or replace function public.replacement_case_refresh_completion(p_case_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.replacement_cases rc
  set
    status = case
      when rc.status in ('cancelled', 'rejected') then rc.status
      when rc.forward_status = 'delivered'
       and rc.reverse_status in ('picked_up', 'returned')
        then 'completed'
      when rc.status = 'completed'
        then case
          when rc.forward_status = 'delivered'
            and rc.reverse_status in ('picked_up', 'returned')
          then 'completed'
          else 'failed'
        end
      else rc.status
    end,
    completed_at = case
      when rc.forward_status = 'delivered'
       and rc.reverse_status in ('picked_up', 'returned')
        then coalesce(rc.completed_at, now())
      else rc.completed_at
    end,
    updated_at = now()
  where rc.id = p_case_id;
end;
$$;

create or replace function public.replacement_case_after_logistics_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if old.forward_status is distinct from new.forward_status
       or old.reverse_status is distinct from new.reverse_status then
      perform public.replacement_case_refresh_completion(new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_replacement_case_after_logistics_sync on public.replacement_cases;
create trigger trg_replacement_case_after_logistics_sync
after update of forward_status, reverse_status
on public.replacement_cases
for each row execute function public.replacement_case_after_logistics_sync();

create or replace function public.admin_set_replacement_logistics(
  p_replacement_case_id uuid,
  p_logistics_mode text default null,
  p_forward_shipment_id text default null,
  p_reverse_shipment_id text default null,
  p_forward_awb_code text default null,
  p_reverse_awb_code text default null,
  p_forward_tracking_url text default null,
  p_reverse_tracking_url text default null,
  p_forward_status text default null,
  p_reverse_status text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_active_admin(v_uid) then
    raise exception 'not_authorized';
  end if;

  update public.replacement_cases
  set
    logistics_mode = coalesce(nullif(trim(coalesce(p_logistics_mode, '')), ''), logistics_mode),
    forward_shipment_id = coalesce(nullif(trim(coalesce(p_forward_shipment_id, '')), ''), forward_shipment_id),
    reverse_shipment_id = coalesce(nullif(trim(coalesce(p_reverse_shipment_id, '')), ''), reverse_shipment_id),
    forward_awb_code = coalesce(nullif(trim(coalesce(p_forward_awb_code, '')), ''), forward_awb_code),
    reverse_awb_code = coalesce(nullif(trim(coalesce(p_reverse_awb_code, '')), ''), reverse_awb_code),
    forward_tracking_url = coalesce(nullif(trim(coalesce(p_forward_tracking_url, '')), ''), forward_tracking_url),
    reverse_tracking_url = coalesce(nullif(trim(coalesce(p_reverse_tracking_url, '')), ''), reverse_tracking_url),
    forward_status = coalesce(nullif(trim(coalesce(p_forward_status, '')), ''), forward_status),
    reverse_status = coalesce(nullif(trim(coalesce(p_reverse_status, '')), ''), reverse_status),
    updated_at = now()
  where id = p_replacement_case_id;

  if not found then
    raise exception 'replacement_case_not_found';
  end if;

  perform public.replacement_case_refresh_completion(p_replacement_case_id);
end;
$$;

revoke all on function public.admin_set_replacement_logistics(uuid, text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.admin_set_replacement_logistics(uuid, text, text, text, text, text, text, text, text, text) to authenticated;
