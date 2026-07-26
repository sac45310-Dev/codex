-- Security hardening, three layers:
--
-- 1) Enable RLS on the two sales tables that were missing it. Every other
--    sales.* table runs RLS-on with zero policies (deny-by-default); all
--    access goes through SECURITY DEFINER RPCs owned by postgres, and
--    postgres owns these tables, so definer functions and pg_cron are
--    unaffected. Deliberately NOT "force row level security" — that would
--    subject the owner (and thus every definer RPC) to the empty policy set.
alter table sales.scout_hunt_queue enable row level security;
alter table sales.prospect_sync_state enable row level security;

-- 2) Defense-in-depth: strip any direct table privileges from client roles
--    so a future GRANT USAGE on the schema cannot silently expose them.
revoke all on table sales.scout_hunt_queue from public, anon, authenticated;
revoke all on table sales.prospect_sync_state from public, anon, authenticated;

-- 3) Close the live hole: these internal cron ticks had EXECUTE granted to
--    PUBLIC/anon and no in-body authorization, so anyone with the anon key
--    could fire them via PostgREST RPC (draining the hunt queue and invoking
--    the lead-scout / lead-assist edge functions). pg_cron runs them as
--    their owner (postgres), which keeps EXECUTE regardless; edge functions
--    and trusted callers use service_role.
revoke execute on function public.scout_hunt_tick() from public, anon, authenticated;
revoke execute on function public.lead_research_tick() from public, anon, authenticated;
grant execute on function public.scout_hunt_tick() to service_role;
grant execute on function public.lead_research_tick() to service_role;
