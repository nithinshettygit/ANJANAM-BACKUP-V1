-- Refund auditability for production financial controls.

alter table public.orders
  add column if not exists refund_initiated_by text,
  add column if not exists refund_initiated_at timestamptz,
  add column if not exists refund_reason text;

comment on column public.orders.refund_initiated_by is
  'Admin identifier (email/id) who initiated the refund.';
comment on column public.orders.refund_initiated_at is
  'Timestamp when refund was initiated by admin.';
comment on column public.orders.refund_reason is
  'Optional admin-entered reason for refund.';
