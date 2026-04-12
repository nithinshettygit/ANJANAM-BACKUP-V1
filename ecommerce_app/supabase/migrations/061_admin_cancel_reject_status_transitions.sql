-- Rejecting a customer cancellation restores the order to pre_cancel_status
-- (processing or packed) via public.admin_reject_order_cancellation.
-- Migration 057 tightened orders_valid_status_transition to only
-- cancel_requested → cancelled | cancel_rejected, which broke that RPC.
-- Allow direct return to processing/packed (same as migration 035 graph).

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
    when 'payment_failed' then lower(trim(p_new)) in (
      'processing',
      'cancel_requested',
      'cancelled'
    )
    when 'payment_failed_inventory' then lower(trim(p_new)) = 'payment_failed_inventory'
    when 'out_of_stock_after_payment' then lower(trim(p_new)) = 'out_of_stock_after_payment'
    when 'processing' then lower(trim(p_new)) in ('packed', 'cancel_requested', 'cancelled')
    when 'packed' then lower(trim(p_new)) in ('shipped', 'cancel_requested', 'cancelled')
    when 'shipped' then lower(trim(p_new)) in ('out_for_delivery')
    when 'out_for_delivery' then lower(trim(p_new)) in ('delivered')
    when 'delivered' then lower(trim(p_new)) = 'delivered'
    when 'cancel_requested' then lower(trim(p_new)) in (
      'cancelled',
      'cancel_rejected',
      'processing',
      'packed'
    )
    when 'cancel_rejected' then lower(trim(p_new)) in ('processing', 'packed', 'shipped', 'out_for_delivery')
    when 'cancelled' then lower(trim(p_new)) = 'cancelled'
    else false
  end;
$$;
