-- Admin notifications: in-app alerts + event trigger pipeline.

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null check (
    type in (
      'order_created',
      'low_stock',
      'out_of_stock',
      'new_user',
      'product_review',
      'product_question',
      'return_request',
      'refund_request'
    )
  ),
  title text not null,
  message text not null,
  reference_id uuid null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  priority text not null default 'low' check (priority in ('high', 'medium', 'low'))
);

create index if not exists idx_admin_notifications_created_desc
  on public.admin_notifications (created_at desc);
create index if not exists idx_admin_notifications_unread_created
  on public.admin_notifications (is_read, created_at desc);
create index if not exists idx_admin_notifications_type_ref
  on public.admin_notifications (type, reference_id);

-- De-duplicate same event object for id-based notification types.
create unique index if not exists uq_admin_notifications_type_reference
  on public.admin_notifications (type, reference_id)
  where reference_id is not null;

alter table public.admin_notifications enable row level security;
alter table public.admin_notifications force row level security;

drop policy if exists "admin_notifications_select_admin" on public.admin_notifications;
create policy "admin_notifications_select_admin"
on public.admin_notifications
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin_notifications_update_admin" on public.admin_notifications;
create policy "admin_notifications_update_admin"
on public.admin_notifications
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Keep insert/delete internal (trigger/service role only).
drop policy if exists "admin_notifications_insert_none" on public.admin_notifications;
drop policy if exists "admin_notifications_delete_none" on public.admin_notifications;

create or replace function public.create_admin_notification(
  p_type text,
  p_title text,
  p_message text,
  p_reference_id uuid default null,
  p_priority text default 'low'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.admin_notifications (type, title, message, reference_id, priority)
  values (p_type, p_title, p_message, p_reference_id, p_priority)
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    return null;
end;
$$;

-- New order created
create or replace function public.trg_admin_notify_order_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_label text;
begin
  v_label := upper(substr(new.id::text, 1, 8));
  perform public.create_admin_notification(
    'order_created',
    'New Order Received',
    format('Order #%s has been placed.', v_label),
    new.id,
    'high'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_order_created on public.orders;
create trigger trg_admin_notify_order_created
after insert on public.orders
for each row execute function public.trg_admin_notify_order_created();

-- Product stock checks (low / out-of-stock) without duplicates.
create or replace function public.trg_admin_notify_product_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold int := 5;
  v_available int;
  v_title text;
  v_msg text;
begin
  v_available := greatest(0, coalesce(new.inventory_count, 0) - coalesce(new.reserved_quantity, 0));

  if v_available = 0 then
    v_title := 'Out Of Stock';
    v_msg := format('%s is now out of stock.', coalesce(nullif(trim(new.title), ''), 'Product'));
    perform public.create_admin_notification(
      'out_of_stock',
      v_title,
      v_msg,
      new.id,
      'high'
    );
  elsif v_available < v_threshold then
    v_title := 'Low Stock Alert';
    v_msg := format('%s stock is running low.', coalesce(nullif(trim(new.title), ''), 'Product'));
    perform public.create_admin_notification(
      'low_stock',
      v_title,
      v_msg,
      new.id,
      'medium'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_admin_notify_product_stock on public.products;
create trigger trg_admin_notify_product_stock
after insert or update of inventory_count, reserved_quantity on public.products
for each row
execute function public.trg_admin_notify_product_stock();

-- New user signup
create or replace function public.trg_admin_notify_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.create_admin_notification(
    'new_user',
    'New User Registered',
    format('%s just created an account.', coalesce(nullif(trim(new.email), ''), 'A user')),
    new.id,
    'low'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_new_user on public.profiles;
create trigger trg_admin_notify_new_user
after insert on public.profiles
for each row execute function public.trg_admin_notify_new_user();

-- Product review added
create or replace function public.trg_admin_notify_product_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_name text;
begin
  select coalesce(nullif(trim(p.title), ''), 'product')
  into v_product_name
  from public.products p
  where p.id = new.product_id;

  perform public.create_admin_notification(
    'product_review',
    'New Product Review',
    format('A new review was posted for %s', coalesce(v_product_name, 'product')),
    new.id,
    'low'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_product_review on public.reviews;
create trigger trg_admin_notify_product_review
after insert on public.reviews
for each row execute function public.trg_admin_notify_product_review();

-- Product question asked
create or replace function public.trg_admin_notify_product_question()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_name text;
begin
  select coalesce(nullif(trim(p.title), ''), 'product')
  into v_product_name
  from public.products p
  where p.id = new.product_id;

  perform public.create_admin_notification(
    'product_question',
    'Customer Question',
    format('A new question was asked about %s', coalesce(v_product_name, 'product')),
    new.id,
    'medium'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_product_question on public.product_questions;
create trigger trg_admin_notify_product_question
after insert on public.product_questions
for each row execute function public.trg_admin_notify_product_question();

-- Return request created
create or replace function public.trg_admin_notify_return_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_label text;
begin
  v_order_label := upper(substr(new.order_id::text, 1, 8));
  perform public.create_admin_notification(
    'return_request',
    'Return Request',
    format('Return requested for Order #%s', v_order_label),
    new.id,
    'high'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_return_request on public.returns;
create trigger trg_admin_notify_return_request
after insert on public.returns
for each row execute function public.trg_admin_notify_return_request();

-- Refund request created
create or replace function public.trg_admin_notify_refund_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_label text;
begin
  v_order_label := upper(substr(new.order_id::text, 1, 8));
  perform public.create_admin_notification(
    'refund_request',
    'Refund Requested',
    format('Refund requested for Order #%s', v_order_label),
    new.id,
    'high'
  );
  return new;
end;
$$;

drop trigger if exists trg_admin_notify_refund_request on public.refunds;
create trigger trg_admin_notify_refund_request
after insert on public.refunds
for each row execute function public.trg_admin_notify_refund_request();

-- Realtime stream support for admin_notifications.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'admin_notifications'
  ) then
    alter publication supabase_realtime add table public.admin_notifications;
  end if;
end $$;

-- Optional push dispatch hook:
-- If pg_net is enabled and app settings are configured, this trigger calls
-- Edge Function `send-notification` with action=admin_notification.
create or replace function public.dispatch_admin_notification_push(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_url text := nullif(current_setting('app.settings.supabase_url', true), '');
  v_service_key text := nullif(current_setting('app.settings.service_role_key', true), '');
begin
  if p_notification_id is null then
    return;
  end if;

  -- Requires `net.http_post` extension + runtime settings. If unavailable, no-op.
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'net' and p.proname = 'http_post'
  ) then
    return;
  end if;

  if v_base_url is null or v_service_key is null then
    return;
  end if;

  perform net.http_post(
    url := v_base_url || '/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := jsonb_build_object(
      'action', 'admin_notification',
      'notification_id', p_notification_id::text
    )
  );
exception
  when others then
    -- Push dispatch must never break the writer transaction.
    return;
end;
$$;

create or replace function public.trg_admin_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.dispatch_admin_notification_push(new.id);
  return new;
end;
$$;

drop trigger if exists trg_admin_notification_push on public.admin_notifications;
create trigger trg_admin_notification_push
after insert on public.admin_notifications
for each row execute function public.trg_admin_notification_push();
