-- Admin-editable invoice and parcel-label settings.
create table if not exists public.document_settings (
  id smallint primary key default 1 check (id = 1),
  seller_legal_name text not null default 'Anjanam',
  seller_address text not null default 'MUGU,Kasaragod,Kerala,India,671321',
  seller_phone text not null default '+91 81291 07108',
  seller_email text not null default 'support.anjanam@gmail.com',
  seller_gstin text,
  default_hsn_sac text,
  show_tax_breakup boolean not null default false,
  cgst_rate numeric(6,3) not null default 0 check (cgst_rate >= 0 and cgst_rate <= 100),
  sgst_rate numeric(6,3) not null default 0 check (sgst_rate >= 0 and sgst_rate <= 100),
  igst_rate numeric(6,3) not null default 0 check (igst_rate >= 0 and igst_rate <= 100),
  place_of_supply text,
  label_from_address text not null default 'Anjanam\nAnjanam Warehouse\nMUGU, Kasaragod\nKerala, India 671321\n+91 81291 07108',
  label_carrier_name text,
  updated_at timestamptz not null default now()
);

insert into public.document_settings (id)
values (1)
on conflict (id) do nothing;

drop trigger if exists trg_document_settings_updated_at on public.document_settings;
create trigger trg_document_settings_updated_at
before update on public.document_settings
for each row execute function public.set_updated_at();

alter table public.document_settings enable row level security;
alter table public.document_settings force row level security;

drop policy if exists "document_settings_select_authenticated" on public.document_settings;
create policy "document_settings_select_authenticated"
on public.document_settings
for select
to authenticated
using (true);

drop policy if exists "document_settings_update_admin" on public.document_settings;
create policy "document_settings_update_admin"
on public.document_settings
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
