-- Email auto-attach for the sales CRM: called by crm-inbound (Resend BCC
-- webhook) and gmail-sync (Gmail polling). Matches every sales contact on
-- the From/To/Cc lists and logs an email_in/email_out activity on each
-- matching lead. Dedupes on the provider message id. Service-role/staff only.
create or replace function public.sales_attach_email(p json)
returns int language plpgsql security definer
set search_path to 'public','sales' as $$
declare
  v_all_emails text[];
  v_count int := 0;
  v_lead record;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;

  -- Already attached? (same provider message id anywhere)
  if exists (select 1 from sales.activities
             where meta->>'msg_id' = p->>'msg_id' and p->>'msg_id' is not null) then
    return 0;
  end if;

  select array_agg(distinct lower(trim(e))) into v_all_emails
  from (
    select p->>'from_email' as e
    union all
    select json_array_elements_text(coalesce(p->'to_emails','[]'::json))
  ) s where e is not null and e <> '';

  for v_lead in
    select distinct c.lead_id, min(c.id::text)::uuid as contact_id
    from sales.contacts c
    where lower(c.email) = any (v_all_emails)
    group by c.lead_id
  loop
    insert into sales.activities (lead_id, contact_id, kind, subject, body, actor_email, meta)
    values (
      v_lead.lead_id, v_lead.contact_id,
      case when p->>'direction' = 'out' then 'email_out' else 'email_in' end,
      left(p->>'subject', 300),
      left(p->>'snippet', 2000),
      p->>'from_email',
      json_build_object('msg_id', p->>'msg_id', 'via', coalesce(p->>'via','email'))::jsonb
    );
    update sales.leads set updated_at = now() where id = v_lead.lead_id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;
revoke execute on function public.sales_attach_email(json) from public, anon;
grant execute on function public.sales_attach_email(json) to authenticated, service_role;
