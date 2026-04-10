-- Automated Razorpay refunds on orders table.

alter table public.orders
  add column if not exists refund_status text not null default 'none',
  add column if not exists refund_amount integer,
  add column if not exists refund_id text,
  add column if not exists refund_requested_at timestamptz,
  add column if not exists refund_processed_at timestamptz;

alter table public.orders
  drop constraint if exists orders_refund_status_check;

alter table public.orders
  add constraint orders_refund_status_check
  check (
    refund_status in (
      'none',
      'requested',
      'approved',
      'processing',
      'refunded',
      'rejected'
    )
  );

create index if not exists idx_orders_refund_status
  on public.orders (refund_status);

comment on column public.orders.refund_status is
  'Order-level refund lifecycle for gateway refunds.';
comment on column public.orders.refund_amount is
  'Refund amount in paise for Razorpay API calls.';
comment on column public.orders.refund_id is
  'Gateway refund identifier returned by Razorpay.';
