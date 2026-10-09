-- Apply after 0002_business_signup.sql.
-- Preserve invoice metadata when syncing to another device.
alter table public.documents add column if not exists client_name text;
alter table public.documents add column if not exists client_phone text;
alter table public.documents add column if not exists notes text;
alter table public.documents add column if not exists payment_option text;
-- Deny document number changes after issuing in a future server-side
-- finalization workflow. Drafts are not legally finalized invoices.
