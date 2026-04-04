-- Strict sequential refund_status transitions (financial reporting safety).

create or replace function public.refunds_enforce_status_transition()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.refund_status is not distinct from new.refund_status then
    return new;
  end if;

  if old.refund_status = 'refund_completed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  if old.refund_status = 'refund_initiated'
     and new.refund_status is distinct from 'refund_processed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  if old.refund_status = 'refund_processed'
     and new.refund_status is distinct from 'refund_completed' then
    raise exception 'invalid_refund_status_transition';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_refunds_enforce_status_transition on public.refunds;

create trigger trg_refunds_enforce_status_transition
before update of refund_status on public.refunds
for each row
execute function public.refunds_enforce_status_transition();

comment on function public.refunds_enforce_status_transition() is
  'Allows only refund_initiated→refund_processed→refund_completed; blocks regressions and skips.';
