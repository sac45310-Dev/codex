-- Scout weekly report (2026-07-22): one JSON blob for the Monday section of
-- the sales-daily-queue email — keeps the learning loop visible so the
-- review queue doesn't silently rot. Guard matches sales_scout_brain:
-- service_role (the cron email) or platform staff.
create or replace function public.sales_scout_weekly()
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
    'filed_7d', (select count(*) from sales.scout_candidates
                 where created_at > now() - interval '7 days'),
    'approved_7d', (select count(*) from sales.scout_candidates
                    where reviewed_at > now() - interval '7 days'
                      and status = 'approved'),
    'rejected_7d', (select count(*) from sales.scout_candidates
                    where reviewed_at > now() - interval '7 days'
                      and status = 'rejected'),
    'queue_depth', (select count(*) from sales.scout_candidates
                    where status = 'pending'),
    'avg_fit_pending', (select round(avg(fit_score), 1)
                        from sales.scout_candidates
                        where status = 'pending' and fit_score is not null),
    'top_angles', coalesce((select json_agg(row_to_json(a)) from (
      select source_query as angle,
             count(*) filter (where status = 'approved') as approved,
             count(*) filter (where status in ('approved','rejected')) as reviewed
      from sales.scout_candidates
      where source_query is not null
      group by source_query
      having count(*) filter (where status in ('approved','rejected')) > 0
      order by (count(*) filter (where status = 'approved'))::numeric
               / greatest(count(*) filter (where status in ('approved','rejected')), 1) desc,
               count(*) filter (where status in ('approved','rejected')) desc
      limit 3) a), '[]'::json));
end $$;

revoke execute on function public.sales_scout_weekly() from public, anon;
grant execute on function public.sales_scout_weekly() to authenticated, service_role;
