create or replace function public.sales_list_leads(
  p_search text default null, p_status text default null, p_stage text default null,
  p_limit integer default 50, p_offset integer default 0)
returns json language plpgsql stable security definer
set search_path to 'public', 'sales'
as $function$
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
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
    where (
        p_status is null
        or (p_status = 'open'     and l.status <> 'customer' and coalesce(d.stage, '') <> 'won')
        or (p_status = 'customer' and (l.status = 'customer' or d.stage = 'won'))
        or (p_status not in ('open', 'customer') and l.status = p_status)
      )
      and (p_stage is null or d.stage = p_stage)
      and (p_search is null or l.org_name ilike '%'||p_search||'%'
           or exists (select 1 from sales.contacts c where c.lead_id = l.id
                      and (c.name ilike '%'||p_search||'%' or c.email ilike '%'||p_search||'%')))
    order by coalesce(l.score, 0) desc, l.updated_at desc
    limit least(p_limit, 200) offset p_offset) x), '[]'::json);
end $function$;

drop function if exists public.sales_scout_list();
create or replace function public.sales_scout_list(p_limit int default 30, p_offset int default 0)
returns json language plpgsql stable security definer
set search_path to 'public', 'sales'
as $function$
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'pending', coalesce((select json_agg(row_to_json(x) order by x.fit_score desc nulls last, x.created_at desc)
      from (
        select c.*,
               (select count(*) from sales.contacts ct where ct.scout_candidate_id = c.id) as contact_count
        from sales.scout_candidates c where c.status = 'pending'
        order by c.fit_score desc nulls last, c.created_at desc
        limit least(p_limit, 100) offset p_offset
      ) x), '[]'::json),
    'archive', coalesce((select json_agg(row_to_json(r)) from (
      select id, org_name, org_type, website, city, state, status,
             left(summary, 200) as summary, fit_score, review_note, reviewed_at
      from sales.scout_candidates where status in ('rejected', 'skipped')
      order by reviewed_at desc limit 50) r), '[]'::json),
    'counts', (select json_build_object(
      'pending',  count(*) filter (where status = 'pending'),
      'approved', count(*) filter (where status = 'approved'),
      'rejected', count(*) filter (where status = 'rejected'),
      'skipped',  count(*) filter (where status = 'skipped'))
      from sales.scout_candidates));
end $function$;

revoke execute on function public.sales_scout_list(int, int) from public, anon;
grant execute on function public.sales_scout_list(int, int) to authenticated, service_role;
