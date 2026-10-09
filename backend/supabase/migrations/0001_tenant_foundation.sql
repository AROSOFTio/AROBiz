-- ARODesk SaaS foundation. Apply ONLY to a dedicated, reviewed Supabase project.
-- All tenant-owned rows carry business_id. Never expose service-role keys in Flutter.
create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  category text,
  currency text not null default 'UGX',
  logo_url text,
  accent_color text,
  address text,
  phone text,
  email text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.business_memberships (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'staff', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

-- SECURITY DEFINER helper avoids membership-policy recursion. Fix search path,
-- schema-qualify relations and keep member lookup scoped to auth.uid().
create schema if not exists private;
create or replace function private.has_business_role(p_business uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(
    select 1 from public.business_memberships m
    where m.business_id = p_business
      and m.user_id = (select auth.uid())
      and m.role = any(p_roles)
  );
$$;
revoke all on function private.has_business_role(uuid,text[]) from public;
grant usage on schema private to authenticated;
grant execute on function private.has_business_role(uuid,text[]) to authenticated;

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  display_name text not null,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  contact_id uuid,
  type text not null check(type in ('invoice','quotation','receipt','proforma','delivery_note','credit_note')),
  status text not null default 'draft',
  document_number text,
  currency text not null default 'UGX',
  issue_date date not null,
  due_date date,
  lines jsonb not null default '[]'::jsonb,
  subtotal numeric(18,2) not null default 0,
  tax_total numeric(18,2) not null default 0,
  discount_total numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  sync_version bigint not null default 1,
  created_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (business_id,document_number),
  unique (business_id,id),
  foreign key (business_id, contact_id) references public.contacts(business_id,id)
);
alter table public.contacts add constraint contacts_business_id_id_unique unique (business_id,id);

create table if not exists public.payments (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  document_id uuid not null,
  amount numeric(18,2) not null check(amount > 0),
  currency text not null,
  paid_at timestamptz not null,
  method text,
  created_by uuid not null references auth.users(id),
  unique(business_id,id),
  foreign key (business_id, document_id) references public.documents(business_id,id)
);

-- Initial creation of businesses and their owner memberships MUST happen
-- together via a reviewed SECURITY DEFINER RPC / edge function. Do not grant
-- clients arbitrary INSERT on memberships or allow direct self-elevation.

alter table public.businesses enable row level security;
alter table public.business_memberships enable row level security;
alter table public.contacts enable row level security;
alter table public.documents enable row level security;
alter table public.payments enable row level security;

create policy businesses_read on public.businesses for select to authenticated
  using (private.has_business_role(id, array['owner','admin','staff','viewer']));
create policy businesses_update on public.businesses for update to authenticated
  using (private.has_business_role(id, array['owner','admin']))
  with check (private.has_business_role(id, array['owner','admin']));
create policy memberships_read on public.business_memberships for select to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff','viewer']));
create policy contacts_read on public.contacts for select to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff','viewer']));
create policy contacts_insert on public.contacts for insert to authenticated
  with check (private.has_business_role(business_id,array['owner','admin','staff']));
create policy contacts_update on public.contacts for update to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff']))
  with check (private.has_business_role(business_id,array['owner','admin','staff']));
create policy documents_read on public.documents for select to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff','viewer']));
create policy documents_insert on public.documents for insert to authenticated
  with check (created_by = (select auth.uid()) and private.has_business_role(business_id,array['owner','admin','staff']));
create policy documents_update on public.documents for update to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff']))
  with check (private.has_business_role(business_id,array['owner','admin','staff']));
create policy payments_read on public.payments for select to authenticated
  using (private.has_business_role(business_id,array['owner','admin','staff','viewer']));
create policy payments_insert on public.payments for insert to authenticated
  with check (created_by = (select auth.uid()) and private.has_business_role(business_id,array['owner','admin','staff']));

-- Server-side validation and tests remain required before production:
-- totals must be recalculated server-side, document finalization must use
-- authoritative sequencing, roles must be enforced via privileged endpoints.
