-- Enrichment writes contacts at SCOUT level (contacts.scout_candidate_id).
-- On approval, sales_scout_review created the lead but LEFT those contacts
-- pointing at the scout — so the promoted lead's outreach couldn't see them.
-- Fix: re-parent the scout's contacts to the new lead atomically (the
-- exactly-one-parent CHECK stays satisfied: scout_candidate_id -> null,
-- lead_id -> the new lead). Brand-new lead has no contacts, so the
-- (lead_id, name) unique index can't collide.
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
    -- carry enriched contacts from the scout to the new lead
    update sales.contacts
       set lead_id = v_lead, scout_candidate_id = null
     where scout_candidate_id = p_id;
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
