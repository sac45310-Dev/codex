-- Scout queue shows enrichment progress: each pending candidate carries a
-- contact_count, and sales_scout_contacts fetches the enriched contacts for
-- one candidate (for the expand/skip UI).
create or replace function public.sales_scout_list()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return json_build_object(
    'pending', coalesce((select json_agg(row_to_json(x) order by x.fit_score desc nulls last, x.created_at desc)
      from (
        select c.*,
               (select count(*) from sales.contacts ct where ct.scout_candidate_id = c.id) as contact_count
        from sales.scout_candidates c where c.status = 'pending'
      ) x), '[]'::json),
    'archive', coalesce((select json_agg(row_to_json(r)) from (
      select id, org_name, org_type, website, city, state, status,
             left(summary, 200) as summary, fit_score, review_note, reviewed_at
      from sales.scout_candidates where status in ('rejected', 'skipped')
      order by reviewed_at desc limit 50) r), '[]'::json),
    'counts', (select json_build_object(
      'pending',  count(*) filter (where status = 'pending'),
      'approved', count(*) filter (where status = 'approved'),
      'rejected', count(*) filter (where status = 'rejected'),
      'skipped',  count(*) filter (where status = 'skipped'))
      from sales.scout_candidates));
end $$;

create or replace function public.sales_scout_contacts(p_id uuid)
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return coalesce((select json_agg(row_to_json(c) order by c.confidence desc nulls last, c.created_at)
    from sales.contacts c where c.scout_candidate_id = p_id), '[]'::json);
end $$;
revoke execute on function public.sales_scout_contacts(uuid) from public, anon;
grant execute on function public.sales_scout_contacts(uuid) to authenticated;
