-- Automatic lead research (founder: "automatically please", 2026-07-22).
-- A permanent pg_cron sweep gives every lead a person-profile dossier:
-- every 3 minutes, pick ONE lead whose notes lack an "AI RESEARCH" block
-- and POST lead-assist's new cron-secret service lane for it. New approvals
-- still get instant research from the console; this catches calibration
-- approvals, failed browser invocations, and hand-added leads — then goes
-- quiet (no leads missing research → no-op, zero spend).
--
-- Service lane RPCs (service_role ONLY — the sales schema stays off
-- PostgREST, so the edge function needs these two narrow doors):

create or replace function public.sales_service_lead_brief(p_id uuid)
returns json
language plpgsql stable security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'Not authorized';
  end if;
  return (select json_build_object(
    'id', l.id, 'org_name', l.org_name, 'org_type', l.org_type,
    'website', l.website, 'city', l.city, 'state', l.state, 'notes', l.notes)
  from sales.leads l where l.id = p_id);
end $$;

create or replace function public.sales_service_append_research(p_id uuid, p_text text)
returns void
language plpgsql security definer
set search_path to 'public', 'sales'
as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'Not authorized';
  end if;
  update sales.leads
     set notes = left(coalesce(nullif(trim(coalesce(notes,'')), '') || E'\n\n', '')
                 || '— AI RESEARCH ' || to_char(now(), 'YYYY-MM-DD')
                 || ' (verify before relying on it) —' || E'\n'
                 || left(p_text, 3000), 8000),
         updated_at = now()
   where id = p_id;
end $$;

revoke execute on function public.sales_service_lead_brief(uuid) from public, anon, authenticated;
grant execute on function public.sales_service_lead_brief(uuid) to service_role;
revoke execute on function public.sales_service_append_research(uuid, text) from public, anon, authenticated;
grant execute on function public.sales_service_append_research(uuid, text) to service_role;

-- The sweep tick: one unresearched lead per firing, oldest first.
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

select cron.schedule('lead-research-sweep', '*/3 * * * *',
  $$ select public.lead_research_tick(); $$);
