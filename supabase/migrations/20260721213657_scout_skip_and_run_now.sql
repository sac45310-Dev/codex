-- Scout verdicts v3 (founder feedback, 2026-07-22):
--  * SKIP — the middle verdict for "fine but uninspiring" candidates:
--    kept out of the queue AND out of the never-again reject list, stored
--    as a LUKEWARM teaching example (the scout learns to aim higher, not
--    to avoid the whole category). Restorable like rejects.
--  * sales_scout_run_now() — the "Find more leads" button: staff-triggered
--    on-demand hunt via pg_net → lead-scout (action 'run', cron secret
--    read server-side so it never touches the browser). Async by design;
--    fresh candidates land in the queue within a minute or two.

alter table sales.scout_candidates
  drop constraint if exists scout_candidates_status_check;
alter table sales.scout_candidates
  add constraint scout_candidates_status_check
  check (status in ('pending', 'approved', 'rejected', 'skipped'));

create or replace function public.sales_scout_skip(p_id uuid, p_reason text default null)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  update sales.scout_candidates
     set status = 'skipped',
         reviewed_by = auth.jwt()->>'email',
         reviewed_at = now(),
         review_note = left(nullif(trim(coalesce(p_reason,'')), ''), 200)
   where id = p_id and status = 'pending';
  if not found then raise exception 'Candidate not found or already reviewed'; end if;
end $$;

-- Archive now carries BOTH non-approved verdicts, labeled.
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

create or replace function public.sales_scout_restore(p_id uuid)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_c sales.scout_candidates;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  select * into v_c from sales.scout_candidates
   where id = p_id and status in ('rejected', 'skipped');
  if not found then raise exception 'Candidate not found or not archived'; end if;
  update sales.scout_candidates
     set status = 'pending',
         meta = meta || jsonb_build_object(
           'prior_verdict', v_c.status,
           'prior_reject_reason', coalesce(v_c.review_note, ''),
           'restored_at', now(),
           'restored_by', auth.jwt()->>'email'),
         review_note = null,
         reviewed_by = null,
         reviewed_at = null
   where id = p_id;
end $$;

-- Brain: skipped counts per angle + recent lukewarm examples for the prompt.
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
             count(*) filter (where status = 'rejected') as rejected,
             count(*) filter (where status = 'skipped') as skipped
      from sales.scout_candidates where source_query is not null
      group by source_query) a), '[]'::json),
    'approved_examples', coalesce((select json_agg(row_to_json(x)) from (
      select org_name, org_type, state, left(summary, 200) as summary
      from sales.scout_candidates where status = 'approved'
      order by reviewed_at desc limit 5) x), '[]'::json),
    'skipped_examples', coalesce((select json_agg(row_to_json(s)) from (
      select org_name, org_type, state, left(summary, 200) as summary, review_note as reason
      from sales.scout_candidates where status = 'skipped'
      order by reviewed_at desc limit 5) s), '[]'::json),
    'rejected_examples', coalesce((select json_agg(row_to_json(y)) from (
      select org_name, org_type, state, left(summary, 200) as summary, review_note as reason
      from sales.scout_candidates where status = 'rejected'
      order by reviewed_at desc limit 5) y), '[]'::json));
end $$;

-- "Find more leads": fire an on-demand hunt. The cron secret stays
-- server-side; pg_net delivers asynchronously and lead-scout files results
-- through the normal dedupe/ingest path.
create or replace function public.sales_scout_run_now()
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_secret text;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  select value into v_secret from public.app_config where key = 'cron_secret';
  if v_secret is null then raise exception 'cron_secret not configured'; end if;
  perform net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/lead-scout',
    headers := jsonb_build_object(
      'Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := jsonb_build_object('action', 'run'),
    timeout_milliseconds := 150000);
end $$;

revoke execute on function public.sales_scout_skip(uuid, text) from public, anon;
grant execute on function public.sales_scout_skip(uuid, text) to authenticated;
revoke execute on function public.sales_scout_run_now() from public, anon;
grant execute on function public.sales_scout_run_now() to authenticated;
