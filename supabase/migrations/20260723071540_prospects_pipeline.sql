-- Prospect Pipeline: Auto-Load Scouts & Decision-Makers
-- Additive, read-only over existing data. New writable object: sales.prospect_sync_state.

create or replace function sales.confidence_tier(p_confidence smallint)
returns text language sql immutable as $$
  select case
    when p_confidence is null then 'unknown'
    when p_confidence >= 9 then 'primary'
    when p_confidence >= 7 then 'secondary'
    when p_confidence >= 5 then 'role'
    when p_confidence >= 3 then 'org'
    else 'low'
  end
$$;

create or replace view sales.v_prospect_contact_map as
  select c.scout_candidate_id as prospect_id, c.id as contact_id
    from sales.contacts c
   where c.scout_candidate_id is not null
  union
  select unnest(c.scout_candidate_ids) as prospect_id, c.id as contact_id
    from sales.contacts c
   where c.scout_candidate_ids is not null
     and array_length(c.scout_candidate_ids, 1) > 0;

create or replace view sales.v_prospect_contacts as
  select
    m.prospect_id, c.id as contact_id, c.name, c.title, c.email, c.email_kind,
    c.org_email, c.phone, c.phone_kind, c.org_phone, c.linkedin_url, c.city, c.state,
    c.confidence, sales.confidence_tier(c.confidence) as confidence_tier,
    c.is_primary, c.verified, c.source_url, c.enriched_at, c.created_at
  from sales.v_prospect_contact_map m
  join sales.contacts c on c.id = m.contact_id;

create or replace view sales.v_prospects as
  select
    s.id as prospect_id, s.org_name, sales.norm_org_type(s.org_type) as org_type,
    s.org_type as org_type_raw, s.website, sales.url_domain(s.website) as domain,
    s.city, s.state, s.status, s.summary, s.fit_score, s.fit_reason, s.source_query,
    s.lead_id, s.created_at,
    count(pc.contact_id) as contact_count,
    count(*) filter (where pc.confidence >= 9)            as primary_count,
    count(*) filter (where pc.confidence between 7 and 8) as secondary_count,
    count(*) filter (where pc.confidence between 5 and 6) as role_count,
    count(*) filter (where pc.confidence between 3 and 4) as org_count,
    max(pc.confidence)                                    as best_confidence,
    bool_or(pc.email is not null)                         as has_direct_email,
    bool_or(pc.phone is not null)                         as has_phone
  from sales.scout_candidates s
  left join sales.v_prospect_contacts pc on pc.prospect_id = s.id
  group by s.id;

create table if not exists sales.prospect_sync_state (
  user_id        uuid primary key,
  last_synced_at timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create or replace function public.sales_prospects_list(
  p_search text default null, p_org_type text default null, p_status text[] default null,
  p_state text default null, p_min_confidence int default null, p_has_email boolean default null,
  p_has_phone boolean default null, p_only_with_contacts boolean default false,
  p_since timestamptz default null, p_sort text default 'newest',
  p_limit int default 50, p_offset int default 0
)
returns json language plpgsql stable security definer
set search_path to 'public', 'sales'
as $function$
declare
  v_status text[] := coalesce(p_status, array['pending','approved']);
  v_limit  int    := least(greatest(coalesce(p_limit, 50), 1), 500);
  v_offset int    := greatest(coalesce(p_offset, 0), 0);
  v_total  int;
  v_rows   json;
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;

  with filtered as (
    select p.* from sales.v_prospects p
    where (v_status is null or p.status = any(v_status))
      and (p_org_type is null or p.org_type = p_org_type)
      and (p_state is null or p.state = p_state)
      and (p_since is null or p.created_at >= p_since)
      and (p_min_confidence is null or coalesce(p.best_confidence, 0) >= p_min_confidence)
      and (p_has_email is null or p.has_direct_email = p_has_email)
      and (p_has_phone is null or p.has_phone = p_has_phone)
      and (p_only_with_contacts is not true or p.contact_count > 0)
      and (p_search is null or p_search = ''
           or p.org_name ilike '%' || p_search || '%'
           or coalesce(p.domain, '') ilike '%' || p_search || '%'
           or coalesce(p.city, '') ilike '%' || p_search || '%')
  )
  select count(*)::int into v_total from filtered;

  with filtered as (
    select p.* from sales.v_prospects p
    where (v_status is null or p.status = any(v_status))
      and (p_org_type is null or p.org_type = p_org_type)
      and (p_state is null or p.state = p_state)
      and (p_since is null or p.created_at >= p_since)
      and (p_min_confidence is null or coalesce(p.best_confidence, 0) >= p_min_confidence)
      and (p_has_email is null or p.has_direct_email = p_has_email)
      and (p_has_phone is null or p.has_phone = p_has_phone)
      and (p_only_with_contacts is not true or p.contact_count > 0)
      and (p_search is null or p_search = ''
           or p.org_name ilike '%' || p_search || '%'
           or coalesce(p.domain, '') ilike '%' || p_search || '%'
           or coalesce(p.city, '') ilike '%' || p_search || '%')
    order by
      case when p_sort = 'name'                                       then p.org_name end asc,
      case when p_sort = 'contacts'                                   then p.contact_count end desc,
      case when p_sort = 'confidence'                                 then p.best_confidence end desc,
      case when p_sort = 'fit'                                        then p.fit_score end desc,
      case when p_sort not in ('name','contacts','confidence','fit')  then p.created_at end desc,
      p.created_at desc
    limit v_limit offset v_offset
  )
  select coalesce(json_agg(row_to_json(f)), '[]'::json) into v_rows from filtered f;

  return json_build_object('total', v_total, 'limit', v_limit, 'offset', v_offset, 'rows', v_rows);
end
$function$;

create or replace function public.sales_prospect_detail(p_id uuid)
returns json language plpgsql stable security definer
set search_path to 'public', 'sales'
as $function$
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
  return (
    select json_build_object(
      'prospect', row_to_json(p),
      'contacts', coalesce((
        select json_agg(row_to_json(c) order by
          c.is_primary desc, c.confidence desc nulls last, c.created_at)
        from sales.v_prospect_contacts c where c.prospect_id = p.prospect_id
      ), '[]'::json)
    )
    from sales.v_prospects p where p.prospect_id = p_id
  );
end
$function$;

create or replace function public.sales_prospects_summary()
returns json language plpgsql stable security definer
set search_path to 'public', 'sales'
as $function$
declare
  v_uid  uuid := auth.uid();
  v_last timestamptz;
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
  select last_synced_at into v_last from sales.prospect_sync_state where user_id = v_uid;
  return json_build_object(
    'total_prospects', (select count(*) from sales.scout_candidates where status in ('pending','approved')),
    'total_contacts',  (select count(distinct contact_id) from sales.v_prospect_contact_map),
    'by_status', (select coalesce(json_object_agg(status, n), '{}'::json)
                  from (select status, count(*) n from sales.scout_candidates group by status) s),
    'by_tier', json_build_object(
      'primary',   (select count(*) from sales.v_prospect_contacts where confidence >= 9),
      'secondary', (select count(*) from sales.v_prospect_contacts where confidence between 7 and 8),
      'role',      (select count(*) from sales.v_prospect_contacts where confidence between 5 and 6),
      'org',       (select count(*) from sales.v_prospect_contacts where confidence between 3 and 4)
    ),
    'last_synced_at', v_last,
    'new_since_sync', (select count(*) from sales.scout_candidates
                       where status in ('pending','approved') and (v_last is null or created_at > v_last))
  );
end
$function$;

create or replace function public.sales_prospects_mark_synced()
returns json language plpgsql volatile security definer
set search_path to 'public', 'sales'
as $function$
declare v_uid uuid := auth.uid();
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
  if v_uid is null then raise exception 'No authenticated user'; end if;
  insert into sales.prospect_sync_state (user_id, last_synced_at, updated_at)
  values (v_uid, now(), now())
  on conflict (user_id) do update set last_synced_at = now(), updated_at = now();
  return json_build_object('ok', true, 'last_synced_at', now());
end
$function$;

grant execute on function public.sales_prospects_list(
  text, text, text[], text, int, boolean, boolean, boolean, timestamptz, text, int, int
) to authenticated, service_role;
grant execute on function public.sales_prospect_detail(uuid) to authenticated, service_role;
grant execute on function public.sales_prospects_summary() to authenticated, service_role;
grant execute on function public.sales_prospects_mark_synced() to authenticated, service_role;
