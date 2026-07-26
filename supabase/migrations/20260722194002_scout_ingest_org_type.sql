create or replace function public.sales_scout_ingest(p json)
returns integer language plpgsql security definer
set search_path to 'public','sales' as $$
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
      sales.norm_org_type(v_c->>'org_type'),
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
