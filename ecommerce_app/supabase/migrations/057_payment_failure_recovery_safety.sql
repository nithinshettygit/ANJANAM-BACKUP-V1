-- Payment recovery safety: structured internal logs + post-payment failure statuses.

create table if not exists public.system_error_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  error_type text not null,
  order_id uuid references public.orders (id) on delete set null,
  payment_id text,
  error_message text,
  stack_trace text
);

create index if not exists idx_system_error_logs_created_at
  on public.system_error_logs (created_at desc);

create index if not exists idx_system_error_logs_order_id
  on public.system_error_logs (order_id)
  where order_id is not null;

alter table public.orders drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check check (
    status in (
      'pending_payment',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'processing',
      'packed',
      'shipped',
      'out_for_delivery',
      'delivered',
      'cancel_requested',
      'cancel_rejected',
      'cancelled'
    )
  );

create or replace function public.orders_valid_status_transition(p_old text, p_new text)
returns boolean
language sql
immutable
as $$
  select case lower(trim(p_old))
    when 'placed' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'pending' then lower(trim(p_new)) in (
      'pending_payment',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'pending_payment' then lower(trim(p_new)) in (
      'processing',
      'payment_failed',
      'payment_failed_inventory',
      'out_of_stock_after_payment',
      'cancel_requested',
      'cancelled'
    )
    when 'payment_failed' then lower(trim(p_new)) in ('cancel_requested', 'cancelled')
    when 'payment_failed_inventory' then lower(trim(p_new)) = 'payment_failed_inventory'
    when 'out_of_stock_after_payment' then lower(trim(p_new)) = 'out_of_stock_after_payment'
    when 'processing' then lower(trim(p_new)) in ('packed', 'cancel_requested', 'cancelled')
    when 'packed' then lower(trim(p_new)) in ('shipped', 'cancel_requested', 'cancelled')
    when 'shipped' then lower(trim(p_new)) in ('out_for_delivery')
    when 'out_for_delivery' then lower(trim(p_new)) in ('delivered')
    when 'delivered' then lower(trim(p_new)) = 'delivered'
    when 'cancel_requested' then lower(trim(p_new)) in ('cancelled', 'cancel_rejected')
    when 'cancel_rejected' then lower(trim(p_new)) in ('processing', 'packed', 'shipped', 'out_for_delivery')
    when 'cancelled' then lower(trim(p_new)) = 'cancelled'
    else false
  end;
$$;
