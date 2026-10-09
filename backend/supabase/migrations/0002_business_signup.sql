-- Apply in Supabase SQL editor after 0001_tenant_foundation.sql.
-- Allows a signed-in user to create only a business they own.
create or replace function public.create_my_business(
 p_name text,
 p_category text default null,
 p_currency text default 'USD',
 p_address text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
 v_business uuid;
 v_owner uuid := auth.uid();
begin
 if v_owner is null then
   raise exception 'Authentication required';
 end if;
 if p_name is null or length(trim(p_name)) < 1 or length(p_name) > 160 then
   raise exception 'Business name is required (max 160 characters)';
 end if;
 if p_currency is null or p_currency !~ '^[A-Z]{3}$' then
   raise exception 'Currency must be a three-letter ISO code';
 end if;
 insert into public.businesses(name,category,currency,address,created_by)
 values(trim(p_name),p_category,p_currency,p_address,v_owner)
 returning id into v_business;
 insert into public.business_memberships(business_id,user_id,role)
 values(v_business,v_owner,'owner');
 return v_business;
end;
$$;
revoke all on function public.create_my_business(text,text,text,text) from public;
grant execute on function public.create_my_business(text,text,text,text) to authenticated;
