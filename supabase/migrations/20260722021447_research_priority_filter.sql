create or replace function public.lead_research_tick()
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
declare v_id uuid; v_secret text;
begin
  select l.id into v_id from sales.leads l
   where l.status <> 'disqualified'
     and coalesce(l.notes, '') not like '%AI RESEARCH%'
     and (
       exists (select 1 from sales.scout_candidates c
                where c.lead_id = l.id and c.fit_score >= 9)
       or l.org_name ~* '\y(cru|youth for christ|yfc|young life|navigators)\y'
     )
   order by l.created_at limit 1;
  if v_id is null then return; end if;
  select value into v_secret from public.app_config where key = 'cron_secret';
  perform net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/lead-assist',
    headers := jsonb_build_object(
      'Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := jsonb_build_object('action', 'dossier', 'lead_id', v_id, 'service', true),
    timeout_milliseconds := 150000);
end $$;
