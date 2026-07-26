-- AI lead scout scaffold (#89 item 1). A daily edge fn (lead-scout) asks
-- Claude + web search for candidate ministries and files them into
-- sales.scout_candidates for HUMAN review in the console (CRM → Scout).
-- Approving a candidate creates a lead + deal (source 'scrape'); rejecting
-- remembers it so it is never re-suggested. Nothing is ever contacted
-- automatically — no outreach until legal review. The edge fn soft-offs
-- until anthropic_api_key lands in app_config.

create table sales.scout_candidates (
  id uuid primary key default gen_random_uuid(),
  org_name text not null,
  org_type text not null default 'ministry',
  website text,
  city text,
  state text,
  summary text,
  source_query text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  reviewed_by text,
  reviewed_at timestamptz,
  lead_id uuid references sales.leads(id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table sales.scout_candidates enable row level security;
create index scout_candidates_status on sales.scout_candidates (status, created_at desc);
-- A website is identity: once suggested (whatever the verdict), never again.
create unique index scout_candidates_website_uniq
  on sales.scout_candidates (lower(website)) where website is not null;

-- Feeder (edge fn, service role) + staff can hand-add. Dedupes against every
-- prior candidate AND existing leads by org name or website.
create or replace function public.sales_scout_ingest(p json)
returns integer
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_c json; v_count int := 0;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;
  for v_c in select * from json_array_elements(coalesce(p->'candidates','[]'::json))
  loop
    continue when coalesce(trim(v_c->>'org_name'),'') = '';
    continue when exists (select 1 from sales.scout_candidates sc
      where lower(sc.org_name) = lower(v_c->>'org_name')
         or (v_c->>'website' is not null and sc.website is not null
             and lower(sc.website) = lower(v_c->>'website')));
    continue when exists (select 1 from sales.leads l
      where lower(l.org_name) = lower(v_c->>'org_name')
         or (v_c->>'website' is not null and l.website is not null
             and lower(l.website) = lower(v_c->>'website')));
    insert into sales.scout_candidates (org_name, org_type, website, city, state,
                                        summary, source_query, meta)
    values (
      left(v_c->>'org_name', 200),
      case when v_c->>'org_type' in ('ministry','church','nonprofit','missionary','other')
           then v_c->>'org_type' else 'ministry' end,
      left(v_c->>'website', 300),
      left(v_c->>'city', 100),
      left(v_c->>'state', 40),
      left(v_c->>'summary', 1000),
      left(p->>'source_query', 300),
      coalesce(v_c->'meta','{}'::json)::jsonb)
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

create or replace function public.sales_scout_list()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'pending', coalesce((select json_agg(row_to_json(c) order by c.created_at desc)
      from sales.scout_candidates c where c.status = 'pending'), '[]'::json),
    'counts', (select json_build_object(
      'pending',  count(*) filter (where status = 'pending'),
      'approved', count(*) filter (where status = 'approved'),
      'rejected', count(*) filter (where status = 'rejected'))
      from sales.scout_candidates));
end $$;

-- Approve → lead + deal owned by the reviewer (mirrors sales_upsert_lead's
-- insert path); reject → remembered so the scout never re-suggests it.
create or replace function public.sales_scout_review(p_id uuid, p_approve boolean)
returns uuid
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_c sales.scout_candidates; v_lead uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  select * into v_c from sales.scout_candidates where id = p_id and status = 'pending';
  if not found then raise exception 'Candidate not found or already reviewed'; end if;
  if p_approve then
    insert into sales.leads (org_name, org_type, website, city, state, source,
                             owner_email, notes)
    values (v_c.org_name, v_c.org_type, v_c.website, v_c.city, v_c.state, 'scrape',
            auth.jwt()->>'email', v_c.summary)
    returning id into v_lead;
    insert into sales.deals (lead_id, owner_email)
    values (v_lead, auth.jwt()->>'email');
  end if;
  update sales.scout_candidates
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = auth.jwt()->>'email',
         reviewed_at = now(),
         lead_id = v_lead
   where id = p_id;
  return v_lead;
end $$;

revoke execute on function public.sales_scout_ingest(json) from public, anon;
grant execute on function public.sales_scout_ingest(json) to authenticated, service_role;
revoke execute on function public.sales_scout_list() from public, anon;
grant execute on function public.sales_scout_list() to authenticated;
revoke execute on function public.sales_scout_review(uuid, boolean) from public, anon;
grant execute on function public.sales_scout_review(uuid, boolean) to authenticated;

-- Daily scout run (soft-off inside the fn until anthropic_api_key is set).
select cron.schedule(
  'sales-lead-scout-daily',
  '0 13 * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/lead-scout',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
