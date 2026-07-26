-- Console outreach send support. The sales schema is never exposed to
-- PostgREST, so the sales-outreach-send edge fn resolves its recipient
-- through this single guarded RPC: the contact must belong to the lead and
-- have an email, and the privacy blocklist is checked in the same call.
create or replace function public.sales_outreach_context(p_lead_id uuid, p_contact_id uuid)
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
declare v json;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;
  select json_build_object(
           'id', c.id, 'name', c.name, 'email', c.email,
           'blocked', sales.is_blocked(array[lower(c.email)]))
    into v
    from sales.contacts c
   where c.id = p_contact_id and c.lead_id = p_lead_id
     and coalesce(c.email,'') <> '';
  return v; -- null → no such contact on this lead / contact has no email
end $$;

revoke execute on function public.sales_outreach_context(uuid, uuid) from public, anon;
grant execute on function public.sales_outreach_context(uuid, uuid) to authenticated, service_role;
