-- Market-parity polish pass over the analytics pack:
--  * Funnel now counts "ever reached" from sales.stage_history (a lost deal
--    that reached demo still counts at new/contacted/demo — the current-stage
--    funnel silently dropped it) + avg days-in-stage per step.
--  * Weekly activity is a CONTINUOUS 8-week axis (zero weeks included).
--  * sales_get_lead exposes score_parts so the console can explain a score.
--  * sales_search also matches contact phone numbers.

-- Funnel + time-in-stage, embedded in the dashboard payload.
create or replace function public.sales_dashboard()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'by_stage', (select coalesce(json_object_agg(stage, n), '{}'::json) from
      (select stage, count(*) n from sales.deals d
        join sales.leads l on l.id = d.lead_id
        where l.status not in ('disqualified') group by stage) s),
    -- "Ever reached at least this stage" via history ordinals; avg_days is
    -- mean completed dwell time in the stage (null until data accrues).
    'funnel', (select json_agg(row_to_json(f) order by f.ord) from (
      select v.stage, v.ord,
        (select count(distinct h.deal_id) from sales.stage_history h
          where case h.to_stage when 'new' then 1 when 'contacted' then 2
                 when 'demo' then 3 when 'trial' then 4 when 'won' then 5 else 0 end >= v.ord) as reached,
        (select round(avg(extract(epoch from (d.next_at - d.changed_at)) / 86400)::numeric, 1)
           from (select h.*, lead(h.changed_at) over (partition by h.deal_id order by h.changed_at) as next_at
                 from sales.stage_history h) d
          where d.to_stage = v.stage and d.next_at is not null) as avg_days
      from (values ('new',1),('contacted',2),('demo',3),('trial',4),('won',5)) v(stage, ord)) f),
    'leads_total', (select count(*) from sales.leads where status <> 'disqualified'),
    'due_today', (select count(*) from sales.activities
      where done_at is null and due_at is not null
        and due_at < date_trunc('day', now() + interval '1 day')),
    'new_7d', (select count(*) from sales.leads where created_at > now() - interval '7 days'),
    'pipeline_cents', (select coalesce(sum(value_cents),0) from sales.deals
      where stage not in ('won','lost')),
    'won_total', (select count(*) from sales.deals where stage = 'won'),
    'visits_7d', (select count(*) from sales.link_hits
      where created_at > now() - interval '7 days'),
    'hot_leads', coalesce((select json_agg(x) from (
      select l.id, l.org_name, count(*) as hits, max(h.created_at) as last_visit
      from sales.link_hits h join sales.leads l on l.id = h.lead_id
      where h.created_at > now() - interval '48 hours'
      group by l.id, l.org_name
      order by max(h.created_at) desc limit 10) x), '[]'::json)
  );
end $$;

-- Continuous 8-week axis for the weekly chart.
create or replace function public.sales_analytics()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'forecast', (select json_build_object(
        'open_cents', coalesce(sum(value_cents), 0),
        'weighted_cents', coalesce(sum(round(value_cents *
          case stage when 'new' then 0.10 when 'contacted' then 0.25
                     when 'demo' then 0.50 when 'trial' then 0.75 else 0 end)), 0))
      from sales.deals where stage not in ('won','lost')),
    'outreach_30d', (select json_build_object(
        'sent', count(*) filter (where kind = 'email_out'),
        'replies', count(*) filter (where kind = 'email_in'),
        'meetings', count(*) filter (where kind = 'meeting'),
        'calls', count(*) filter (where kind = 'call'))
      from sales.activities where created_at > now() - interval '30 days'),
    'weekly', (select json_agg(row_to_json(w) order by w.week_start) from (
      select to_char(gs, 'MM/DD') as week, gs as week_start,
             (select count(*) from sales.activities a
               where date_trunc('week', a.created_at) = gs
                 and a.kind in ('email_out','call','meeting','text')) as touches,
             (select count(*) from sales.activities a
               where date_trunc('week', a.created_at) = gs
                 and a.kind = 'email_in') as replies
      from generate_series(date_trunc('week', now()) - interval '7 weeks',
                           date_trunc('week', now()), interval '1 week') gs) w),
    'winloss', (select json_build_object(
        'won', count(*) filter (where stage = 'won'),
        'lost', count(*) filter (where stage = 'lost'),
        'lost_reasons', coalesce((select json_agg(row_to_json(r)) from (
          select coalesce(nullif(trim(lost_reason),''),'(no reason)') as reason, count(*) as n
          from sales.deals where stage = 'lost'
          group by 1 order by n desc limit 8) r), '[]'::json))
      from sales.deals),
    'scout', coalesce((select json_agg(row_to_json(s) order by s.total desc) from (
      select coalesce(source_query, '(manual)') as angle,
             count(*) as total,
             count(*) filter (where status = 'approved') as approved,
             count(*) filter (where status = 'rejected') as rejected
      from sales.scout_candidates
      group by source_query limit 12) s), '[]'::json));
end $$;

-- Search also matches phone numbers.
create or replace function public.sales_search(p_q text)
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
declare q text := '%' || trim(coalesce(p_q,'')) || '%';
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  if length(trim(coalesce(p_q,''))) < 2 then return json_build_object(
    'leads','[]'::json,'contacts','[]'::json,'activities','[]'::json); end if;
  return json_build_object(
    'leads', coalesce((select json_agg(row_to_json(x)) from (
      select l.id, l.org_name, l.city, l.state, l.status, d.stage
      from sales.leads l left join sales.deals d on d.lead_id = l.id
      where l.org_name ilike q or l.city ilike q or l.notes ilike q or l.website ilike q
      order by l.updated_at desc limit 10) x), '[]'::json),
    'contacts', coalesce((select json_agg(row_to_json(y)) from (
      select c.id, c.name, c.title, c.email, c.phone, c.lead_id, l.org_name
      from sales.contacts c join sales.leads l on l.id = c.lead_id
      where c.name ilike q or c.email ilike q or c.title ilike q or c.phone ilike q
      order by c.created_at desc limit 10) y), '[]'::json),
    'activities', coalesce((select json_agg(row_to_json(z)) from (
      select a.id, a.kind, a.subject, left(a.body, 160) as snippet,
             a.created_at, a.lead_id, l.org_name
      from sales.activities a join sales.leads l on l.id = a.lead_id
      where a.subject ilike q or a.body ilike q
      order by a.created_at desc limit 15) z), '[]'::json));
end $$;

-- Score transparency: the same components sales_recompute_scores sums (keep
-- the two in lockstep when the formula changes).
create or replace function public.sales_get_lead(p_id uuid)
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return (select json_build_object(
    'lead', row_to_json(l),
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
