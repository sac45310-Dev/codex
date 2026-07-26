-- Scout rejected archive + reactivation. Rejected candidates were already
-- stored forever (dedupe depends on them); this makes them VISIBLE in the
-- console and restorable: sales_scout_restore moves one back to pending,
-- preserving the old verdict in meta (prior_reject_reason / restored_at) so
-- history survives while the live learning loop stops counting it as an
-- avoid-example (the reviewer changed their mind).

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
    'rejected', coalesce((select json_agg(row_to_json(r)) from (
      select id, org_name, org_type, website, city, state,
             left(summary, 200) as summary, fit_score, review_note, reviewed_at
      from sales.scout_candidates where status = 'rejected'
      order by reviewed_at desc limit 50) r), '[]'::json),
    'counts', (select json_build_object(
      'pending',  count(*) filter (where status = 'pending'),
      'approved', count(*) filter (where status = 'approved'),
      'rejected', count(*) filter (where status = 'rejected'))
      from sales.scout_candidates));
end $$;

create or replace function public.sales_scout_restore(p_id uuid)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_c sales.scout_candidates;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  select * into v_c from sales.scout_candidates where id = p_id and status = 'rejected';
  if not found then raise exception 'Candidate not found or not rejected'; end if;
  update sales.scout_candidates
     set status = 'pending',
         meta = meta || jsonb_build_object(
           'prior_reject_reason', coalesce(v_c.review_note, ''),
           'restored_at', now(),
           'restored_by', auth.jwt()->>'email'),
         review_note = null,
         reviewed_by = null,
         reviewed_at = null
   where id = p_id;
end $$;

revoke execute on function public.sales_scout_restore(uuid) from public, anon;
grant execute on function public.sales_scout_restore(uuid) to authenticated;
