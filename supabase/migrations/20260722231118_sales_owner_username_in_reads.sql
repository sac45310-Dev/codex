-- sales_get_lead: add owner_username (resolved) alongside the lead
create or replace function public.sales_get_lead(p_id uuid)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return (select json_build_object(
    'lead', row_to_json(l),
    'owner_username', sales.owner_label(l.owner_email),
    'deal', (select row_to_json(d) from sales.deals d where d.lead_id = l.id),
    'score_parts', json_build_object(
      'visits', case when exists (select 1 from sales.link_hits h
                     where h.lead_id = l.id and h.created_at > now() - interval '48 hours') then 30
                     when exists (select 1 from sales.link_hits h
                     where h.lead_id = l.id and h.created_at > now() - interval '7 days') then 15
                     else 0 end,
      'visit_volume', least((select count(*)::int from sales.link_hits h
                     where h.lead_id = l.id and h.created_at > now() - interval '7 days'), 5) * 2,
      'replies', case when exists (select 1 from sales.activities a
                     where a.lead_id = l.id and a.kind = 'email_in'
                       and a.created_at > now() - interval '7 days') then 30
                     when exists (select 1 from sales.activities a
                     where a.lead_id = l.id and a.kind = 'email_in'
                       and a.created_at > now() - interval '30 days') then 15
                     else 0 end,
      'stage', coalesce((select case d.stage when 'contacted' then 5 when 'demo' then 20
                       when 'trial' then 30 else 0 end from sales.deals d where d.lead_id = l.id), 0),
      'follow_up', case when exists (select 1 from sales.activities a
                       where a.lead_id = l.id and a.done_at is null and a.due_at > now()) then 5
                       else 0 end),
    'contacts', coalesce((select json_agg(row_to_json(c) order by c.is_primary desc, c.created_at)
      from sales.contacts c where c.lead_id = l.id), '[]'::json),
    'links', coalesce((select json_agg(row_to_json(k) order by k.created_at desc)
      from sales.links k where k.lead_id = l.id), '[]'::json),
    'activities', coalesce((select json_agg(row_to_json(a) order by a.created_at desc)
      from (select * from sales.activities where lead_id = l.id
            order by created_at desc limit 100) a), '[]'::json))
  from sales.leads l where l.id = p_id);
end $$;

-- sales_list_leads: add owner_username to each row
create or replace function public.sales_list_leads(p_search text default null, p_status text default null, p_stage text default null, p_limit integer default 50, p_offset integer default 0)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return coalesce((select json_agg(row_to_json(x)) from (
    select l.id, l.org_name, l.org_type, l.city, l.state, l.status, l.score,
           l.owner_email, sales.owner_label(l.owner_email) as owner_username,
           l.source, l.created_at,
           d.stage, d.value_cents, d.stage_changed_at,
           (select json_build_object('name', c.name, 'email', c.email, 'phone', c.phone)
              from sales.contacts c where c.lead_id = l.id
              order by c.is_primary desc, c.created_at limit 1) as primary_contact,
           (select min(a.due_at) from sales.activities a
              where a.lead_id = l.id and a.done_at is null and a.due_at is not null) as next_due
    from sales.leads l
    left join sales.deals d on d.lead_id = l.id
    where (p_status is null or l.status = p_status)
      and (p_stage is null or d.stage = p_stage)
      and (p_search is null or l.org_name ilike '%'||p_search||'%'
           or exists (select 1 from sales.contacts c where c.lead_id = l.id
                      and (c.name ilike '%'||p_search||'%' or c.email ilike '%'||p_search||'%')))
    order by coalesce(l.score, 0) desc, l.updated_at desc
    limit least(p_limit, 200) offset p_offset) x), '[]'::json);
end $$;
