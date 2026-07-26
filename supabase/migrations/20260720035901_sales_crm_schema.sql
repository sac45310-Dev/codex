-- Sales/acquisition CRM (internal-only, ADMIN.md): `sales` schema in the same
-- DB, invisible to tenants. Tables have RLS enabled with NO policies — the
-- only access path is the staff-guarded SECURITY DEFINER sales_* RPCs below
-- (PostgREST doesn't expose the sales schema, and direct grants are revoked).

create schema if not exists sales;
revoke all on schema sales from public, anon, authenticated;

-- ---- tables ---------------------------------------------------------------

create table sales.leads (
  id uuid primary key default gen_random_uuid(),
  org_name text not null,
  org_type text not null default 'ministry'
    check (org_type in ('ministry','church','nonprofit','missionary','other')),
  website text,
  city text,
  state text,
  size_hint text,
  source text not null default 'manual'
    check (source in ('manual','scrape','referral','inbound','event','other')),
  status text not null default 'new'
    check (status in ('new','researching','qualified','disqualified','customer')),
  owner_email text,
  notes text,
  score int check (score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table sales.contacts (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references sales.leads(id) on delete cascade,
  name text not null,
  title text,
  email text,
  phone text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

-- One deal per lead (v1). Stage drives the pipeline board.
create table sales.deals (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null unique references sales.leads(id) on delete cascade,
  stage text not null default 'new'
    check (stage in ('new','contacted','demo','trial','won','lost')),
  value_cents int not null default 34800, -- expected annual value ($29/mo)
  lost_reason text,
  owner_email text,
  stage_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Timeline: calls, emails (in/out), notes, meetings, and tasks (follow-ups
-- when due_at is set; done_at marks completion).
create table sales.activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references sales.leads(id) on delete cascade,
  contact_id uuid references sales.contacts(id) on delete set null,
  kind text not null
    check (kind in ('call','email_out','email_in','note','task','meeting','text')),
  subject text,
  body text,
  due_at timestamptz,
  done_at timestamptz,
  actor_email text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index on sales.leads (status, updated_at desc);
create index on sales.deals (stage);
create index on sales.contacts (lead_id);
create index sales_activities_lead on sales.activities (lead_id, created_at desc);
create index sales_activities_due on sales.activities (due_at) where done_at is null;

alter table sales.leads enable row level security;
alter table sales.contacts enable row level security;
alter table sales.deals enable row level security;
alter table sales.activities enable row level security;

create or replace function sales.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger touch before update on sales.leads
  for each row execute function sales.touch_updated_at();
create trigger touch before update on sales.deals
  for each row execute function sales.touch_updated_at();

-- ---- staff-guarded RPCs ---------------------------------------------------
-- Guard note (CLAUDE.md): always coalesce(platform_role(),'') — a bare
-- platform_role() comparison is NULL for non-staff and never raises.

create or replace function public.sales_dashboard()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
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
    'won_total', (select count(*) from sales.deals where stage = 'won')
  );
end $$;

create or replace function public.sales_list_leads(
  p_search text default null, p_status text default null,
  p_stage text default null, p_limit int default 50, p_offset int default 0)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
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
    order by l.updated_at desc
    limit least(p_limit, 200) offset p_offset) x), '[]'::json);
end $$;

create or replace function public.sales_upsert_lead(p json)
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_id uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  if p->>'id' is not null then
    update sales.leads set
      org_name = coalesce(p->>'org_name', org_name),
      org_type = coalesce(p->>'org_type', org_type),
      website = coalesce(p->>'website', website),
      city = coalesce(p->>'city', city),
      state = coalesce(p->>'state', state),
      size_hint = coalesce(p->>'size_hint', size_hint),
      status = coalesce(p->>'status', status),
      owner_email = coalesce(p->>'owner_email', owner_email),
      notes = coalesce(p->>'notes', notes),
      score = coalesce((p->>'score')::int, score)
    where id = (p->>'id')::uuid
    returning id into v_id;
  else
    insert into sales.leads (org_name, org_type, website, city, state, size_hint,
                             source, owner_email, notes)
    values (p->>'org_name', coalesce(p->>'org_type','ministry'), p->>'website',
            p->>'city', p->>'state', p->>'size_hint',
            coalesce(p->>'source','manual'),
            coalesce(p->>'owner_email', auth.jwt()->>'email'), p->>'notes')
    returning id into v_id;
    insert into sales.deals (lead_id, owner_email)
    values (v_id, coalesce(p->>'owner_email', auth.jwt()->>'email'));
  end if;
  return v_id;
end $$;

create or replace function public.sales_get_lead(p_id uuid)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return (select json_build_object(
    'lead', row_to_json(l),
    'deal', (select row_to_json(d) from sales.deals d where d.lead_id = l.id),
    'contacts', coalesce((select json_agg(row_to_json(c) order by c.is_primary desc, c.created_at)
      from sales.contacts c where c.lead_id = l.id), '[]'::json),
    'activities', coalesce((select json_agg(row_to_json(a) order by a.created_at desc)
      from (select * from sales.activities where lead_id = l.id
            order by created_at desc limit 100) a), '[]'::json))
  from sales.leads l where l.id = p_id);
end $$;

create or replace function public.sales_add_contact(p json)
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_id uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  insert into sales.contacts (lead_id, name, title, email, phone, is_primary)
  values ((p->>'lead_id')::uuid, p->>'name', p->>'title', p->>'email', p->>'phone',
          coalesce((p->>'is_primary')::boolean, false))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.sales_delete_contact(p_id uuid)
returns void language plpgsql security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  delete from sales.contacts where id = p_id;
end $$;

create or replace function public.sales_log_activity(p json)
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_id uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  insert into sales.activities (lead_id, contact_id, kind, subject, body, due_at, actor_email, meta)
  values ((p->>'lead_id')::uuid,
          nullif(p->>'contact_id','')::uuid,
          p->>'kind', p->>'subject', p->>'body',
          nullif(p->>'due_at','')::timestamptz,
          auth.jwt()->>'email',
          coalesce(p->'meta','{}'::json)::jsonb)
  returning id into v_id;
  update sales.leads set updated_at = now() where id = (p->>'lead_id')::uuid;
  return v_id;
end $$;

create or replace function public.sales_complete_task(p_id uuid)
returns void language plpgsql security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  update sales.activities set done_at = now() where id = p_id and done_at is null;
end $$;

create or replace function public.sales_move_deal(p_lead_id uuid, p_stage text, p_lost_reason text default null)
returns void language plpgsql security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  update sales.deals set stage = p_stage, stage_changed_at = now(),
    lost_reason = case when p_stage = 'lost' then p_lost_reason else null end
  where lead_id = p_lead_id;
  if p_stage = 'won' then
    update sales.leads set status = 'customer' where id = p_lead_id;
  end if;
  insert into sales.activities (lead_id, kind, subject, actor_email)
  values (p_lead_id, 'note', 'Stage → ' || p_stage, auth.jwt()->>'email');
end $$;

-- Today queue: open tasks due through end of today, plus stale pipeline leads
-- (no future follow-up scheduled, nothing logged in 7 days).
create or replace function public.sales_today_queue()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
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

-- Lock RPC execution to signed-in users (guards re-check staff role inside).
do $$ declare fn text;
begin
  foreach fn in array array[
    'sales_dashboard()', 'sales_list_leads(text,text,text,int,int)',
    'sales_upsert_lead(json)', 'sales_get_lead(uuid)',
    'sales_add_contact(json)', 'sales_delete_contact(uuid)',
    'sales_log_activity(json)', 'sales_complete_task(uuid)',
    'sales_move_deal(uuid,text,text)', 'sales_today_queue()']
  loop
    execute format('revoke execute on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end $$;
