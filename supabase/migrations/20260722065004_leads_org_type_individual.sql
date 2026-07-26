-- Scout approvals were failing leads_org_type_check: the AI scout labels
-- candidates 'individual' (356 of 448) and 'organization' (54), which the
-- original five-value check refused. Widen the check and normalize any
-- unknown/AI-invented value to 'other' at the insert points.

alter table sales.leads drop constraint leads_org_type_check;
alter table sales.leads add constraint leads_org_type_check
  check (org_type in ('ministry','church','nonprofit','missionary',
                      'individual','organization','other'));

create or replace function sales.norm_org_type(p text)
returns text language sql immutable as $$
  select case when lower(coalesce(p,'')) in
    ('ministry','church','nonprofit','missionary','individual','organization')
  then lower(p) else 'other' end
$$;

create or replace function public.sales_scout_review(p_id uuid, p_approve boolean, p_reason text default null)
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_c sales.scout_candidates; v_lead uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  select * into v_c from sales.scout_candidates where id = p_id and status = 'pending';
  if not found then raise exception 'Candidate not found or already reviewed'; end if;
  if p_approve then
    insert into sales.leads (org_name, org_type, website, city, state, source,
                             owner_email, notes)
    values (v_c.org_name, sales.norm_org_type(v_c.org_type), v_c.website, v_c.city,
            v_c.state, 'scrape', auth.jwt()->>'email', v_c.summary)
    returning id into v_lead;
    insert into sales.deals (lead_id, owner_email)
    values (v_lead, auth.jwt()->>'email');
  end if;
  update sales.scout_candidates
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = auth.jwt()->>'email',
         reviewed_at = now(),
         review_note = left(nullif(trim(coalesce(p_reason,'')), ''), 200),
         lead_id = v_lead
   where id = p_id;
  return v_lead;
end $$;
