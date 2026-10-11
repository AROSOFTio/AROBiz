-- ARODesk workspace foundation (deploy only after review and a database backup)
-- Supabase Postgres: organizations, owners, memberships, branches with tenant RLS.
create extension if not exists pgcrypto;

create table if not exists public.arodesk_organizations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  name text not null check (length(trim(name)) between 2 and 180),
  industry text not null default 'Other',
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.arodesk_memberships (
  organization_id uuid not null references public.arodesk_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager','accountant','cashier','staff')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table if not exists public.arodesk_branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.arodesk_organizations(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  location text,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create index if not exists ardesk_memberships_user_idx on public.arodesk_memberships(user_id);
create index if not exists ardesk_branches_org_idx on public.arodesk_branches(organization_id);

-- DEFINER helpers intentionally bypass memberships RLS recursion.
create or replace function public.arodesk_is_member(target_org uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.arodesk_memberships m
    where m.organization_id = target_org and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.arodesk_is_owner(target_org uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.arodesk_organizations o
    where o.id = target_org and o.owner_id = (select auth.uid())
  );
$$;

revoke all on function public.arodesk_is_member(uuid) from public, anon;
revoke all on function public.arodesk_is_owner(uuid) from public, anon;
grant execute on function public.arodesk_is_member(uuid) to authenticated;
grant execute on function public.arodesk_is_owner(uuid) to authenticated;

create or replace function public.arodesk_initialize_organization()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.arodesk_memberships(organization_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  insert into public.arodesk_branches(organization_id, name, location)
  values (new.id, 'Main Branch', new.location);
  return new;
end;
$$;

drop trigger if exists ardesk_org_init on public.arodesk_organizations;
create trigger ardesk_org_init
after insert on public.arodesk_organizations
for each row execute function public.arodesk_initialize_organization();

alter table public.arodesk_organizations enable row level security;
alter table public.arodesk_memberships enable row level security;
alter table public.arodesk_branches enable row level security;

drop policy if exists "ardesk_org_read" on public.arodesk_organizations;
create policy "ardesk_org_read" on public.arodesk_organizations
for select to authenticated using (public.arodesk_is_member(id));

drop policy if exists "ardesk_org_create" on public.arodesk_organizations;
create policy "ardesk_org_create" on public.arodesk_organizations
for insert to authenticated with check (owner_id = (select auth.uid()));

drop policy if exists "ardesk_org_update" on public.arodesk_organizations;
create policy "ardesk_org_update" on public.arodesk_organizations
for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "ardesk_memberships_read" on public.arodesk_memberships;
create policy "ardesk_memberships_read" on public.arodesk_memberships
for select to authenticated using (public.arodesk_is_member(organization_id));

drop policy if exists "ardesk_memberships_insert" on public.arodesk_memberships;
create policy "ardesk_memberships_insert" on public.arodesk_memberships
for insert to authenticated
with check (
 public.arodesk_is_owner(organization_id)
 and role <> 'owner'
);

drop policy if exists "ardesk_memberships_delete" on public.arodesk_memberships;
create policy "ardesk_memberships_delete" on public.arodesk_memberships
for delete to authenticated using (
 public.arodesk_is_owner(organization_id) and role <> 'owner'
);

drop policy if exists "ardesk_branches_read" on public.arodesk_branches;
create policy "ardesk_branches_read" on public.arodesk_branches
for select to authenticated using (public.arodesk_is_member(organization_id));

drop policy if exists "ardesk_branches_write" on public.arodesk_branches;
create policy "ardesk_branches_write" on public.arodesk_branches
for all to authenticated
using (public.arodesk_is_owner(organization_id))
with check (public.arodesk_is_owner(organization_id));

-- RLS verification required before production:
-- (1) Signup A and create org A; signup B and create org B.
-- (2) Verify A cannot select/insert/update B's organization, branches or memberships.
-- (3) Verify owner bootstrap creates exactly one owner membership and Main Branch.
-- (4) Verify ordinary staff cannot modify organization or add other members.
-- No existing local invoices are migrated by this SQL.
