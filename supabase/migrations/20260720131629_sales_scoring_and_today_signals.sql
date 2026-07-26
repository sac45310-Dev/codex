-- Lead scoring + Today-queue signals (#89 follow-on, roadmap items 2+3).
--
-- Scoring: sales_recompute_scores() fills leads.score (0-100) hourly from
-- engagement signals — transparent, additive, explainable:
--   visits:   +30 tracked-link visit in 48h, else +15 in 7d
--   volume:   +2 per hit in 7d (max +10)
--   replies:  +30 email_in within 7d, else +15 within 30d
--   stage:    contacted +5, demo +20, trial +30
--   momentum: +5 when a follow-up task is scheduled
-- Leads list now orders hottest-first. Like run_self_heal, the fn carries no
-- auth guard (hourly cron runs it as postgres); execute is revoked from
-- anon/public and it leaks nothing (returns a row count).
--
-- Today queue: two suggested-action lists alongside due/stale —
--   hot:          open leads whose tracked links were visited in 48h
--   reply_needed: open leads whose LAST touch is an inbound email (14d)

create or replace function public.sales_recompute_scores()
returns integer
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_n int;
begin
  update sales.leads l set score = least(100,
      case when exists (select 1 from sales.link_hits h
                        where h.lead_id = l.id and h.created_at > now() - interval '48 hours') then 30
           when exists (select 1 from sales.link_hits h
                        where h.lead_id = l.id and h.created_at > now() - interval '7 days') then 15
           else 0 end
    + least((select count(*)::int from sales.link_hits h
             where h.lead_id = l.id and h.created_at > now() - interval '7 days'), 5) * 2
    + case when exists (select 1 from sales.activities a
                        where a.lead_id = l.id and a.kind = 'email_in'
                          and a.created_at > now() - interval '7 days') then 30
           when exists (select 1 from sales.activities a
                        where a.lead_id = l.id and a.kind = 'email_in'
                          and a.created_at > now() - interval '30 days') then 15
           else 0 end
    + coalesce((select case d.stage when 'contacted' then 5 when 'demo' then 20
                                    when 'trial' then 30 else 0 end
                from sales.deals d where d.lead_id = l.id), 0)
    + case when exists (select 1 from sales.activities a
                        where a.lead_id = l.id and a.done_at is null and a.due_at > now()) then 5
           else 0 end)
  where l.status <> 'disqualified';
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function public.sales_recompute_scores() from public, anon;
grant execute on function public.sales_recompute_scores() to authenticated;

-- Hottest first (score desc), then most recently touched.
create or replace function public.sales_list_leads(p_search text default null, p_status text default null, p_stage text default null, p_limit integer default 50, p_offset integer default 0)
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return coalesce((select json_agg(row_to_json(x)) from (
    select l.id, l.org_name, l.org_type, l.city, l.state, l.status, l.score,
           l.owner_email, l.source, l.created_at,
           d.stage, d.value_cents,
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

create or replace function public.sales_today_queue()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'due', coalesce((select json_agg(row_to_json(x)) from (
      select a.id as activity_id, a.subject, a.body, a.due_at, a.kind,
             l.id as lead_id, l.org_name, l.owner_email
      from sales.activities a join sales.leads l on l.id = a.lead_id
      where a.done_at is null and a.due_at is not null
        and a.due_at < date_trunc('day', now() + interval '1 day')
      order by a.due_at limit 50) x), '[]'::json),
    'hot', coalesce((select json_agg(row_to_json(h)) from (
      select l.id as lead_id, l.org_name, max(k.created_at) as last_visit,
             count(*) as hits
      from sales.link_hits k
      join sales.leads l on l.id = k.lead_id
      left join sales.deals d on d.lead_id = l.id
      where k.created_at > now() - interval '48 hours'
        and l.status <> 'disqualified'
        and coalesce(d.stage, 'new') not in ('won','lost')
      group by l.id, l.org_name
      order by max(k.created_at) desc limit 25) h), '[]'::json),
    'reply_needed', coalesce((select json_agg(row_to_json(r)) from (
      select l.id as lead_id, l.org_name, a.created_at as replied_at, a.subject
      from sales.leads l
      join sales.deals d on d.lead_id = l.id and d.stage not in ('won','lost')
      join lateral (
        select a.kind, a.created_at, a.subject from sales.activities a
        where a.lead_id = l.id
          and a.kind in ('email_in','email_out','call','meeting','text')
        order by a.created_at desc limit 1
      ) a on a.kind = 'email_in'
      where l.status <> 'disqualified'
        and a.created_at > now() - interval '14 days'
      order by a.created_at desc limit 25) r), '[]'::json),
    'stale', coalesce((select json_agg(row_to_json(y)) from (
      select l.id as lead_id, l.org_name, l.owner_email, d.stage, l.updated_at
      from sales.leads l join sales.deals d on d.lead_id = l.id
      where l.status in ('new','researching','qualified')
        and d.stage not in ('won','lost')
        and l.updated_at < now() - interval '7 days'
        and not exists (select 1 from sales.activities a
          where a.lead_id = l.id and a.done_at is null and a.due_at > now())
      order by l.updated_at limit 25) y), '[]'::json));
end $$;

select cron.schedule('sales-score-hourly', '35 * * * *',
  $$ select public.sales_recompute_scores(); $$);
-- Prime the scores now rather than waiting for the first tick.
select public.sales_recompute_scores();
