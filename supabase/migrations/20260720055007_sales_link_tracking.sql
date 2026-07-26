-- Sales CRM: outreach link tracking + site-visit attribution (#89 item 2).
-- Staff mint per-lead tracked links (https://donorsend.app<dest>?dsr=<token>)
-- to paste into outreach email. The SPA stashes the token on first hit and
-- beacons every page load to sales_track_visit, so both the click AND return
-- visits attribute to the lead: hits land in sales.link_hits, the timeline
-- gets a 'visit' activity (deduped per browsing session), and the dashboard
-- shows visits_7d + hot leads (visited in the last 48h).

create table sales.links (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references sales.leads(id) on delete cascade,
  -- 12 hex chars; uniqueness enforced, collisions retried by the insert path.
  token text not null unique default left(md5(gen_random_uuid()::text), 12),
  label text,
  dest text not null default '/',
  created_by text,
  hit_count int not null default 0,
  last_hit_at timestamptz,
  created_at timestamptz not null default now()
);
alter table sales.links enable row level security;
create index links_lead on sales.links (lead_id);

create table sales.link_hits (
  id bigint generated always as identity primary key,
  link_id uuid not null references sales.links(id) on delete cascade,
  lead_id uuid not null references sales.leads(id) on delete cascade,
  path text,
  referrer text,
  created_at timestamptz not null default now()
);
alter table sales.link_hits enable row level security;
create index link_hits_link_created on sales.link_hits (link_id, created_at desc);
create index link_hits_lead_created on sales.link_hits (lead_id, created_at desc);

-- Timeline entries for tracked visits.
alter table sales.activities drop constraint activities_kind_check;
alter table sales.activities add constraint activities_kind_check
  check (kind = any (array['call','email_out','email_in','note','task',
                           'meeting','text','visit']));

create or replace function public.sales_create_link(p json)
returns json
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_row sales.links;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  insert into sales.links (lead_id, label, dest, created_by)
  values (
    (p->>'lead_id')::uuid,
    nullif(trim(coalesce(p->>'label','')), ''),
    -- dest is a path on donorsend.app, never a full URL (no open redirect).
    case when coalesce(p->>'dest','') ~ '^/[a-zA-Z0-9_/.-]*$' then p->>'dest' else '/' end,
    auth.jwt()->>'email')
  returning * into v_row;
  return row_to_json(v_row);
end $$;

create or replace function public.sales_delete_link(p_id uuid)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  delete from sales.links where id = p_id;
end $$;

-- PUBLIC beacon (anon, called by the marketing site/SPA). Unknown token is a
-- silent no-op — no error, no token-probing oracle. Abuse-capped per link.
create or replace function public.sales_track_visit(p json)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_link sales.links;
begin
  select * into v_link from sales.links where token = p->>'token';
  if not found then return; end if;

  if (select count(*) from sales.link_hits
      where link_id = v_link.id
        and created_at > now() - interval '1 hour') >= 120 then
    return;
  end if;

  insert into sales.link_hits (link_id, lead_id, path, referrer)
  values (v_link.id, v_link.lead_id, left(p->>'path', 300), left(p->>'referrer', 300));
  update sales.links
     set hit_count = hit_count + 1, last_hit_at = now()
   where id = v_link.id;

  -- One timeline entry per link per 6h — a browsing session reads as a single
  -- visit, not a row per page. Does NOT bump leads.updated_at: the stale list
  -- tracks OUR touches, and a hot visitor going "stale" is exactly the nudge.
  if not exists (select 1 from sales.activities
                 where lead_id = v_link.lead_id and kind = 'visit'
                   and meta->>'link_id' = v_link.id::text
                   and created_at > now() - interval '6 hours') then
    insert into sales.activities (lead_id, kind, subject, body, meta)
    values (v_link.lead_id, 'visit', 'Visited the site',
            coalesce(v_link.label, v_link.dest),
            json_build_object('link_id', v_link.id, 'path', left(p->>'path', 300))::jsonb);
  end if;
end $$;

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
    'contacts', coalesce((select json_agg(row_to_json(c) order by c.is_primary desc, c.created_at)
      from sales.contacts c where c.lead_id = l.id), '[]'::json),
    'links', coalesce((select json_agg(row_to_json(k) order by k.created_at desc)
      from sales.links k where k.lead_id = l.id), '[]'::json),
    'activities', coalesce((select json_agg(row_to_json(a) order by a.created_at desc)
      from (select * from sales.activities where lead_id = l.id
            order by created_at desc limit 100) a), '[]'::json))
  from sales.leads l where l.id = p_id);
end $$;

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

-- Staff-only fns follow the sales convention; the beacon is the one
-- deliberate anon-callable exception (it writes nothing without a valid token).
revoke execute on function public.sales_create_link(json) from public, anon;
grant execute on function public.sales_create_link(json) to authenticated;
revoke execute on function public.sales_delete_link(uuid) from public, anon;
grant execute on function public.sales_delete_link(uuid) to authenticated;
revoke execute on function public.sales_track_visit(json) from public;
grant execute on function public.sales_track_visit(json) to anon, authenticated;
