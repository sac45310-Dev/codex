-- Scout v2: the scout LEARNS from review history (#scout-learning).
--  * fit_score/fit_reason: the scout self-scores each candidate 1-10; the
--    review queue sorts best-first.
--  * reject reasons: sales_scout_review gains p_reason; stored on the
--    candidate and fed back into the scout's AVOID examples.
--  * sales_scout_brain: everything the daily run needs to learn — per-angle
--    approval stats (for weighted angle selection) + recent approved/rejected
--    examples with reasons (for prompt conditioning).
-- Learning improves FINDING only; outreach remains 100% human.

alter table sales.scout_candidates add column fit_score integer;
alter table sales.scout_candidates add column fit_reason text;
alter table sales.scout_candidates add column review_note text;

-- Queue best-first.
create or replace function public.sales_scout_list()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'pending', coalesce((select json_agg(row_to_json(c) order by c.fit_score desc nulls last, c.created_at desc)
      from sales.scout_candidates c where c.status = 'pending'), '[]'::json),
    'counts', (select json_build_object(
      'pending',  count(*) filter (where status = 'pending'),
      'approved', count(*) filter (where status = 'approved'),
      'rejected', count(*) filter (where status = 'rejected'))
      from sales.scout_candidates));
end $$;

-- Review with an optional reason (rejections feed the learning loop).
drop function public.sales_scout_review(uuid, boolean);
create or replace function public.sales_scout_review(p_id uuid, p_approve boolean, p_reason text default null)
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
         review_note = left(nullif(trim(coalesce(p_reason,'')), ''), 200),
         lead_id = v_lead
   where id = p_id;
  return v_lead;
end $$;

-- Ingest now stores the scout's own fit assessment.
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
                                        summary, source_query, fit_score, fit_reason, meta)
    values (
      left(v_c->>'org_name', 200),
      case when v_c->>'org_type' in ('ministry','church','nonprofit','missionary','other')
           then v_c->>'org_type' else 'ministry' end,
      left(v_c->>'website', 300),
      left(v_c->>'city', 100),
      left(v_c->>'state', 40),
      left(v_c->>'summary', 1000),
      left(p->>'source_query', 300),
      least(greatest(nullif(v_c->>'fit_score','')::int, 1), 10),
      left(v_c->>'fit_reason', 300),
      coalesce(v_c->'meta','{}'::json)::jsonb)
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- The scout's memory: what to hunt more of, what to avoid.
create or replace function public.sales_scout_brain()
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;
  return json_build_object(
    'angles', coalesce((select json_agg(row_to_json(a)) from (
      select source_query as angle,
             count(*) filter (where status = 'approved') as approved,
             count(*) filter (where status = 'rejected') as rejected
      from sales.scout_candidates where source_query is not null
      group by source_query) a), '[]'::json),
    'approved_examples', coalesce((select json_agg(row_to_json(x)) from (
      select org_name, org_type, state, left(summary, 200) as summary
      from sales.scout_candidates where status = 'approved'
      order by reviewed_at desc limit 5) x), '[]'::json),
    'rejected_examples', coalesce((select json_agg(row_to_json(y)) from (
      select org_name, org_type, state, left(summary, 200) as summary, review_note as reason
      from sales.scout_candidates where status = 'rejected'
      order by reviewed_at desc limit 5) y), '[]'::json));
end $$;

revoke execute on function public.sales_scout_review(uuid, boolean, text) from public, anon;
grant execute on function public.sales_scout_review(uuid, boolean, text) to authenticated;
revoke execute on function public.sales_scout_brain() from public, anon;
grant execute on function public.sales_scout_brain() to authenticated, service_role;
