-- Product-level GST configuration and immutable order-item tax snapshots.
-- Existing products remain intentionally incomplete until an admin reviews them.

alter table public.products
  add column if not exists hsn_code text,
  add column if not exists gst_rate numeric(6,3),
  add column if not exists tax_status text not null default 'taxable',
  add column if not exists price_includes_gst boolean not null default true;

alter table public.products
  drop constraint if exists products_gst_rate_check;
alter table public.products
  add constraint products_gst_rate_check
  check (gst_rate is null or (gst_rate >= 0 and gst_rate <= 100));

alter table public.products
  drop constraint if exists products_tax_status_check;
alter table public.products
  add constraint products_tax_status_check
  check (tax_status in ('taxable', 'exempt', 'zero_rated'));

alter table public.order_items
  add column if not exists hsn_code text,
  add column if not exists taxable_value numeric(12,2),
  add column if not exists gst_rate numeric(6,3),
  add column if not exists cgst_amount numeric(12,2),
  add column if not exists sgst_amount numeric(12,2),
  add column if not exists igst_amount numeric(12,2),
  add column if not exists tax_status text,
  add column if not exists price_includes_gst boolean;

create or replace function public.snapshot_product_tax_on_order_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  product_tax record;
  gross numeric(12,2);
  tax numeric(12,2);
  customer_state text;
  intra_state boolean;
begin
  if tg_op = 'UPDATE' and new.taxable_value is not null then
    return new;
  end if;

  select p.hsn_code, p.gst_rate, p.tax_status, p.price_includes_gst
    into product_tax
  from public.products p
  where p.id = new.product_id;

  if not found then
    return new;
  end if;

  if coalesce(product_tax.tax_status, 'taxable') = 'taxable'
      and (nullif(trim(product_tax.hsn_code), '') is null
        or product_tax.gst_rate is null) then
    raise exception 'product_tax_configuration_incomplete';
  end if;

  new.hsn_code := nullif(trim(product_tax.hsn_code), '');
  new.tax_status := coalesce(product_tax.tax_status, 'taxable');
  new.price_includes_gst := coalesce(product_tax.price_includes_gst, true);
  new.gst_rate := case
    when new.tax_status = 'taxable' then product_tax.gst_rate
    else 0
  end;

  gross := round(coalesce(new.unit_price, 0) * coalesce(new.quantity, 0), 2);
  if new.tax_status = 'taxable' and coalesce(new.gst_rate, 0) > 0 then
    if new.price_includes_gst then
      new.taxable_value := round(gross / (1 + new.gst_rate / 100), 2);
    else
      new.taxable_value := gross;
    end if;
    tax := round(gross - new.taxable_value, 2);
    if not new.price_includes_gst then
      tax := round(new.taxable_value * new.gst_rate / 100, 2);
    end if;
  else
    new.taxable_value := gross;
    tax := 0;
  end if;

  customer_state := lower(trim(coalesce((select o.shipping_state
    from public.orders o where o.id = new.order_id), '')));
  intra_state := customer_state in ('kerala', '32');
  if intra_state then
    new.cgst_amount := round(tax / 2, 2);
    new.sgst_amount := round(tax - new.cgst_amount, 2);
    new.igst_amount := 0;
  else
    new.cgst_amount := 0;
    new.sgst_amount := 0;
    new.igst_amount := tax;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_order_items_snapshot_product_tax on public.order_items;
create trigger trg_order_items_snapshot_product_tax
before insert on public.order_items
for each row execute function public.snapshot_product_tax_on_order_item();

revoke all on function public.snapshot_product_tax_on_order_item() from public;

create or replace function public.set_order_shipping_state(
  p_order_id uuid,
  p_shipping_state text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set shipping_state = nullif(trim(p_shipping_state), '')
  where id = p_order_id
    and user_id = auth.uid();
  if not found then
    raise exception 'order_not_found';
  end if;
  update public.order_items
  set taxable_value = null
  where order_id = p_order_id;
end;
$$;

revoke all on function public.set_order_shipping_state(uuid, text) from public;
grant execute on function public.set_order_shipping_state(uuid, text) to authenticated;
