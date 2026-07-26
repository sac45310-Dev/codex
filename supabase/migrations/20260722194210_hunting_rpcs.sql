create or replace function sales.url_domain(p_url text)
returns text language sql immutable as $$
  select split_part(regexp_replace(lower(coalesce(p_url,'')), '^https?://(www\.)?', ''), '/', 1)
$$;

create or replace function public.sales_url_record(p json)
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_id uuid; v_url text; v_type text; v_status text;
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  v_url := left(btrim(p->>'url'), 1000);
  if coalesce(v_url,'') = '' then raise exception 'url required'; end if;
  v_type := case when p->>'url_type' in
      ('directory','listing','org_page','person_page','staff_index','unknown')
    then p->>'url_type' else 'unknown' end;
  v_status := case when p->>'scour_status' in
      ('fully_mined','partial','blocked','to_retry','failed')
    then p->>'scour_status' else 'partial' end;
  insert into sales.urls_scoured (url, domain, url_type, scour_status,
    prospects_found, contacts_found, http_status, notes, meta, last_scoured_at)
  values (v_url,
    coalesce(nullif(p->>'domain',''), sales.url_domain(v_url)),
    v_type, v_status,
    coalesce((p->>'prospects_found')::int, 0),
    coalesce((p->>'contacts_found')::int, 0),
    (p->>'http_status')::int,
    left(p->>'notes', 500),
    coalesce(p->'meta','{}'::json)::jsonb, now())
  on conflict (url) do update set
    url_type = excluded.url_type,
    scour_status = excluded.scour_status,
    prospects_found = greatest(sales.urls_scoured.prospects_found, excluded.prospects_found),
    contacts_found  = greatest(sales.urls_scoured.contacts_found,  excluded.contacts_found),
    http_status = coalesce(excluded.http_status, sales.urls_scoured.http_status),
    notes = coalesce(excluded.notes, sales.urls_scoured.notes),
    meta = sales.urls_scoured.meta || excluded.meta,
    last_scoured_at = now(), updated_at = now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.sales_url_skip(p_url text, p_reason text default null, p_url_type text default 'person_page')
returns uuid language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_id uuid; v_url text; v_type text;
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  v_url := left(btrim(p_url), 1000);
  if coalesce(v_url,'') = '' then raise exception 'url required'; end if;
  v_type := case when p_url_type in
      ('directory','listing','org_page','person_page','staff_index','unknown')
    then p_url_type else 'person_page' end;
  insert into sales.urls_scoured (url, domain, url_type, scour_status, exclude, exclude_reason, last_scoured_at)
  values (v_url, sales.url_domain(v_url), v_type, 'blocked', true, left(p_reason,300), now())
  on conflict (url) do update set
    exclude = true, exclude_reason = left(p_reason,300), updated_at = now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.sales_url_unskip(p_url text)
returns void language plpgsql security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  update sales.urls_scoured set exclude=false, exclude_reason=null, scour_status='to_retry', updated_at=now()
   where url = left(btrim(p_url),1000);
end $$;

create or replace function public.sales_url_open(p_domain text default null, p_limit int default 100)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  return coalesce((select json_agg(row_to_json(x)) from (
    select url, domain, url_type, scour_status, prospects_found, contacts_found, last_scoured_at
    from sales.urls_scoured
    where exclude = false and scour_status <> 'fully_mined'
      and (p_domain is null or domain = lower(btrim(p_domain)))
    order by last_scoured_at nulls first
    limit least(greatest(p_limit,1), 500)) x), '[]'::json);
end $$;

create or replace function public.sales_url_seen(p_url text)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  return coalesce(
    (select json_build_object('seen',true,'exclude',exclude,'scour_status',scour_status,
                              'url_type',url_type,'contacts_found',contacts_found)
     from sales.urls_scoured where url = left(btrim(p_url),1000)),
    json_build_object('seen',false));
end $$;

create or replace function public.sales_enrich_claim(p_limit int default 5, p_min_fit int default 0)
returns json language plpgsql security definer
set search_path to 'public','sales' as $$
declare v json;
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  with pick as (
    select sc.id from sales.scout_candidates sc
    where sc.website is not null and sc.status = 'pending'
      and coalesce((sc.meta->>'enrich_done')::boolean, false) = false
      and coalesce(sc.fit_score, 0) >= p_min_fit
      and not exists (select 1 from sales.contacts c where c.scout_candidate_id = sc.id)
      and ( (sc.meta->>'enrich_claimed_at') is null
            or (sc.meta->>'enrich_claimed_at')::timestamptz < now() - interval '30 minutes')
    order by sc.fit_score desc nulls last, sc.created_at
    limit least(greatest(p_limit,1), 25)
    for update skip locked
  ), upd as (
    update sales.scout_candidates sc
      set meta = sc.meta || jsonb_build_object('enrich_claimed_at', now())
      from pick where sc.id = pick.id
      returning sc.id, sc.org_name, sc.website, sc.city, sc.state, sc.fit_score, sc.summary
  )
  select coalesce(json_agg(json_build_object(
    'id', id, 'org_name', org_name, 'website', website,
    'city', city, 'state', state, 'fit_score', fit_score, 'summary', summary)), '[]'::json)
  into v from upd;
  return v;
end $$;

create or replace function public.sales_enrich_write(p json)
returns json language plpgsql security definer
set search_path to 'public','sales' as $$
declare
  v_scout uuid; c json; v_written int := 0; v_name text;
  v_result text; v_attempts int; v_done boolean;
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  v_scout := (p->>'scout_candidate_id')::uuid;
  if not exists (select 1 from sales.scout_candidates where id = v_scout) then
    raise exception 'unknown scout_candidate_id'; end if;
  v_result := coalesce(nullif(p->>'result',''), 'done');

  for c in select * from json_array_elements(coalesce(p->'contacts','[]'::json))
  loop
    v_name := left(btrim(c->>'name'), 120);
    continue when v_name = '';
    update sales.contacts set
      title = left(c->>'title',150),
      email = left(c->>'email',200),
      email_kind = case when c->>'email_kind' in ('direct','role','org') then c->>'email_kind' else null end,
      phone = left(c->>'phone',60),
      phone_kind = case when c->>'phone_kind' in ('direct','extension','org') then c->>'phone_kind' else null end,
      org_email = left(c->>'org_email',200),
      org_phone = left(c->>'org_phone',60),
      linkedin_url = left(c->>'linkedin_url',300),
      address_line1 = left(c->>'address_line1',200),
      address_line2 = left(c->>'address_line2',200),
      city = left(c->>'city',100),
      state = left(c->>'state',60),
      postal_code = left(c->>'postal_code',20),
      country = left(c->>'country',60),
      confidence = least(greatest(nullif(c->>'confidence','')::int,1),10),
      source_url = left(c->>'source_url',500),
      notes = left(c->>'notes',500),
      enriched_at = now()
    where scout_candidate_id = v_scout and lower(btrim(name)) = lower(v_name);
    if not found then
      insert into sales.contacts (scout_candidate_id, name, title, email, email_kind,
        phone, phone_kind, org_email, org_phone, linkedin_url, address_line1, address_line2,
        city, state, postal_code, country, confidence, source_url, notes, enriched_at)
      values (v_scout, v_name, left(c->>'title',150), left(c->>'email',200),
        case when c->>'email_kind' in ('direct','role','org') then c->>'email_kind' else null end,
        left(c->>'phone',60),
        case when c->>'phone_kind' in ('direct','extension','org') then c->>'phone_kind' else null end,
        left(c->>'org_email',200), left(c->>'org_phone',60), left(c->>'linkedin_url',300),
        left(c->>'address_line1',200), left(c->>'address_line2',200), left(c->>'city',100),
        left(c->>'state',60), left(c->>'postal_code',20), left(c->>'country',60),
        least(greatest(nullif(c->>'confidence','')::int,1),10),
        left(c->>'source_url',500), left(c->>'notes',500), now());
    end if;
    v_written := v_written + 1;
  end loop;

  v_attempts := coalesce((select (meta->>'enrich_attempts')::int from sales.scout_candidates where id=v_scout),0) + 1;
  v_done := (v_written > 0) or (v_result = 'none') or (v_attempts >= 3);

  update sales.scout_candidates sc set meta =
    (case when v_done then sc.meta - 'enrich_claimed_at' else sc.meta end)
    || jsonb_build_object('enriched_at', now(), 'enrich_attempts', v_attempts,
                          'enrich_result', v_result, 'enrich_done', v_done)
  where sc.id = v_scout;

  return json_build_object('scout_candidate_id', v_scout, 'written', v_written, 'done', v_done);
end $$;

create or replace function public.sales_enrich_status()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' and coalesce(platform_role(),'')='' then
    raise exception 'Not authorized'; end if;
  return json_build_object(
    'candidates_total', (select count(*) from sales.scout_candidates),
    'with_website', (select count(*) from sales.scout_candidates where website is not null),
    'enriched_orgs', (select count(distinct scout_candidate_id) from sales.contacts where scout_candidate_id is not null),
    'scout_contacts', (select count(*) from sales.contacts where scout_candidate_id is not null),
    'marked_done', (select count(*) from sales.scout_candidates where coalesce((meta->>'enrich_done')::boolean,false)),
    'pending', (select count(*) from sales.scout_candidates sc
      where sc.website is not null and sc.status='pending'
        and coalesce((sc.meta->>'enrich_done')::boolean,false)=false
        and not exists (select 1 from sales.contacts c where c.scout_candidate_id=sc.id)),
    'in_flight', (select count(*) from sales.scout_candidates
      where (meta->>'enrich_claimed_at') is not null
        and (meta->>'enrich_claimed_at')::timestamptz > now() - interval '30 minutes'
        and coalesce((meta->>'enrich_done')::boolean,false)=false),
    'urls_scoured', (select count(*) from sales.urls_scoured),
    'urls_excluded', (select count(*) from sales.urls_scoured where exclude));
end $$;

do $$ declare fn text;
begin
  foreach fn in array array[
    'sales_url_record(json)', 'sales_url_skip(text,text,text)', 'sales_url_unskip(text)',
    'sales_url_open(text,int)', 'sales_url_seen(text)',
    'sales_enrich_claim(int,int)', 'sales_enrich_write(json)', 'sales_enrich_status()']
  loop
    execute format('revoke execute on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated, service_role', fn);
  end loop;
end $$;
