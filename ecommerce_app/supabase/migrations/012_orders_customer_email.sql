-- Snapshot customer email on each order (admin + history) without relying on client auth.users.
alter table public.orders add column if not exists customer_email text;

update public.orders o
set customer_email = nullif(btrim(p.email::text), '')
from public.profiles p
where o.user_id = p.id
  and (o.customer_email is null or btrim(o.customer_email) = '')
  and p.email is not null
  and btrim(p.email::text) <> '';

update public.orders o
set customer_email = nullif(btrim(u.email::text), '')
from auth.users u
where o.user_id = u.id
  and (o.customer_email is null or btrim(o.customer_email) = '')
  and u.email is not null
  and btrim(u.email::text) <> '';

create or replace function public.orders_fill_customer_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.customer_email is not null and btrim(new.customer_email) <> '' then
    return new;
  end if;
  select nullif(btrim(p.email::text), '') into new.customer_email
  from public.profiles p
  where p.id = new.user_id;
  if new.customer_email is not null then
    return new;
  end if;
  select nullif(btrim(u.email::text), '') into new.customer_email
  from auth.users u
  where u.id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_orders_fill_customer_email on public.orders;
create trigger trg_orders_fill_customer_email
before insert on public.orders
for each row
execute function public.orders_fill_customer_email();
