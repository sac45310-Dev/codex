-- Sales CRM analytics pack (approved feature batch 1-7):
--   1. Deal values: sales_set_deal_value + weighted forecast in analytics
--   2. Global search: sales_search across leads/contacts/timeline/notes
--   3. Outreach performance + weekly activity (sales_analytics)
--   4. Auto follow-up nudges: unanswered outreach → a due task (cron daily,
--      TASKS only — never an automated email)
--   5. Stage history: sales.stage_history + deals trigger (data starts
--      accruing now; conversion analytics get real over time)
--   6. Win/loss + scout angle analytics (sales_analytics)
--   7. Deal age on the board: sales_list_leads now returns stage_changed_at

-- ── 5. Stage history ──────────────────────────────────────────────────────
create table sales.stage_history (
  id bigint generated always as identity primary key,
  lead_id uuid not null references sales.leads(id) on delete cascade,
  deal_id uuid not null references sales.deals(id) on delete cascade,
  from_stage text,
  to_stage text not null,
  changed_by text,
  changed_at timestamptz not null default now()
);
alter table sales.stage_history enable row level security;
create index stage_history_lead on sales.stage_history (lead_id, changed_at);

create or replace function sales.log_stage_change() returns trigger
language plpgsql security definer set search_path to 'public', 'sales'
as $$
begin
  if new.stage is distinct from old.stage then
    insert into sales.stage_history (lead_id, deal_id, from_stage, to_stage, changed_by)
    values (new.lead_id, new.id, old.stage, new.stage, auth.jwt()->>'email');
  end if;
  return new;
end $$;
create trigger deals_stage_history
  after update on sales.deals
  for each row execute function sales.log_stage_change();

-- Baseline: one row per existing deal so age/conversion math has a floor.
insert into sales.stage_history (lead_id, deal_id, from_stage, to_stage, changed_at)
select lead_id, id, null, stage, coalesce(stage_changed_at, created_at) from sales.deals;

-- ── 1. Deal value ─────────────────────────────────────────────────────────
create or replace function public.sales_set_deal_value(p_lead_id uuid, p_value_cents integer)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  update sales.deals set value_cents = greatest(coalesce(p_value_cents, 0), 0), updated_at = now()
   where lead_id = p_lead_id;
end $$;

-- ── 2. Global search ──────────────────────────────────────────────────────
-- One box, three buckets: orgs (name/city/notes), people, timeline entries
-- (email subjects/bodies + logged notes). ilike is plenty at this scale.
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
      where c.name ilike q or c.email ilike q or c.title ilike q
      order by c.created_at desc limit 10) y), '[]'::json),
    'activities', coalesce((select json_agg(row_to_json(z)) from (
      select a.id, a.kind, a.subject, left(a.body, 160) as snippet,
             a.created_at, a.lead_id, l.org_name
      from sales.activities a join sales.leads l on l.id = a.lead_id
      where a.subject ilike q or a.body ilike q
      order by a.created_at desc limit 15) z), '[]'::json));
end $$;

-- ── 3+6. Analytics: outreach, weekly activity, win/loss, scout angles ────
create or replace function public.sales_analytics()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    -- Weighted forecast: open pipeline discounted by stage.
    'forecast', (select json_build_object(
        'open_cents', coalesce(sum(value_cents), 0),
        'weighted_cents', coalesce(sum(round(value_cents *
          case stage when 'new' then 0.10 when 'contacted' then 0.25
                     when 'demo' then 0.50 when 'trial' then 0.75 else 0 end)), 0))
      from sales.deals where stage not in ('won','lost')),
    -- Outreach performance, last 30 days.
    'outreach_30d', (select json_build_object(
        'sent', count(*) filter (where kind = 'email_out'),
        'replies', count(*) filter (where kind = 'email_in'),
        'meetings', count(*) filter (where kind = 'meeting'),
        'calls', count(*) filter (where kind = 'call'))
      from sales.activities where created_at > now() - interval '30 days'),
    -- Weekly activity, last 8 ISO weeks (oldest first).
    'weekly', coalesce((select json_agg(row_to_json(w) order by w.week_start) from (
      select to_char(date_trunc('week', a.created_at), 'MM/DD') as week,
             date_trunc('week', a.created_at) as week_start,
             count(*) filter (where a.kind in ('email_out','call','meeting','text')) as touches,
             count(*) filter (where a.kind = 'email_in') as replies
      from sales.activities a
      where a.created_at > date_trunc('week', now()) - interval '7 weeks'
      group by date_trunc('week', a.created_at)) w), '[]'::json),
    -- Win/loss.
    'winloss', (select json_build_object(
        'won', count(*) filter (where stage = 'won'),
        'lost', count(*) filter (where stage = 'lost'),
        'lost_reasons', coalesce((select json_agg(row_to_json(r)) from (
          select coalesce(nullif(trim(lost_reason),''),'(no reason)') as reason, count(*) as n
          from sales.deals where stage = 'lost'
          group by 1 order by n desc limit 8) r), '[]'::json))
      from sales.deals),
    -- Scout angle performance: which hunts produce approvals.
    'scout', coalesce((select json_agg(row_to_json(s) order by s.total desc) from (
      select coalesce(source_query, '(manual)') as angle,
             count(*) as total,
             count(*) filter (where status = 'approved') as approved,
             count(*) filter (where status = 'rejected') as rejected
      from sales.scout_candidates
      group by source_query limit 12) s), '[]'::json));
end $$;

-- ── 4. Auto follow-up nudges (tasks only, never emails) ──────────────────
-- An outreach email 3-14 days old with no inbound reply after it, no open
-- follow-up task, and no prior nudge for that same email → due task today.
create or replace function public.sales_create_followup_nudges()
returns integer
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_n int := 0; r record;
begin
  for r in
    select a.id as email_id, a.lead_id, a.subject
    from sales.activities a
    join sales.deals d on d.lead_id = a.lead_id and d.stage not in ('won','lost')
    join sales.leads l on l.id = a.lead_id and l.status <> 'disqualified'
    where a.kind = 'email_out'
      and a.created_at between now() - interval '14 days' and now() - interval '3 days'
      and not exists (select 1 from sales.activities i
        where i.lead_id = a.lead_id and i.kind = 'email_in' and i.created_at > a.created_at)
      and not exists (select 1 from sales.activities o
        where o.lead_id = a.lead_id and o.kind = 'email_out' and o.created_at > a.created_at)
      and not exists (select 1 from sales.activities t
        where t.lead_id = a.lead_id and t.kind = 'task' and t.done_at is null and t.due_at is not null)
      and not exists (select 1 from sales.activities n
        where n.lead_id = a.lead_id and n.meta->>'nudge_for' = a.id::text)
  loop
    insert into sales.activities (lead_id, kind, subject, body, due_at, meta)
    values (r.lead_id, 'task',
            'Follow up — no reply' || case when r.subject is not null then ' to "'||left(r.subject,80)||'"' else '' end,
            'Auto-suggested: outreach went unanswered. A short bump usually doubles reply rates.',
            now(), json_build_object('nudge_for', r.email_id, 'auto', true)::jsonb);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

revoke execute on function public.sales_set_deal_value(uuid, integer) from public, anon;
grant execute on function public.sales_set_deal_value(uuid, integer) to authenticated;
revoke execute on function public.sales_search(text) from public, anon;
grant execute on function public.sales_search(text) to authenticated;
revoke execute on function public.sales_analytics() from public, anon;
grant execute on function public.sales_analytics() to authenticated;
revoke execute on function public.sales_create_followup_nudges() from public, anon;
grant execute on function public.sales_create_followup_nudges() to authenticated;

-- Nudges daily at 12:45 UTC — lands before the 14:00 daily queue email, so
-- fresh nudges ride along in it.
select cron.schedule('sales-followup-nudges', '45 12 * * *',
  $$ select public.sales_create_followup_nudges(); $$);

-- ── 7. Deal age on the board ─────────────────────────────────────────────
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
