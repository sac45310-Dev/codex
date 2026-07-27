-- Same bug class as scout_hunt_tick / lead_research_tick (fixed in
-- 20260726194553): these are internal background jobs with no in-body
-- authorization check, yet EXECUTE was granted to PUBLIC, so any holder of
-- the anon key could fire them over PostgREST.
--
--   expand_campaigns()   - flips scheduled campaigns to 'expanding' and
--                          expands recipients: can push real donor
--                          SMS/email out ahead of schedule.
--   enqueue_autopilot()  - bulk-inserts into scheduled_messages for EVERY
--                          tenant.
--   run_self_heal()      - mass mutations: soft-deletes donors, resets
--                          campaigns, resolves error groups.
--   fill_donor_timezone()- a trigger function; direct RPC calls just error,
--                          but it has no reason to be exposed either.
--
-- All three cron jobs (campaign-expand, autopilot-enqueue, self-heal) run as
-- `postgres`, which owns these functions and therefore keeps EXECUTE
-- regardless of grants -- the schedules are unaffected. Triggers likewise
-- invoke fill_donor_timezone as the table owner, not the caller.
--
-- authenticated is revoked too, deliberately: enqueue_autopilot and
-- run_self_heal act across all tenants, so any logged-in user calling them
-- would be a cross-tenant escalation. If an admin screen calls one of these
-- directly, the fix is an admin_* SECURITY DEFINER wrapper that checks
-- platform_role() -- the pattern the rest of this schema already uses --
-- not restoring a blanket grant.
revoke execute on function public.expand_campaigns()    from public, anon, authenticated;
revoke execute on function public.enqueue_autopilot()   from public, anon, authenticated;
revoke execute on function public.run_self_heal()       from public, anon, authenticated;
revoke execute on function public.fill_donor_timezone() from public, anon, authenticated;

grant execute on function public.expand_campaigns()  to service_role;
grant execute on function public.enqueue_autopilot() to service_role;
grant execute on function public.run_self_heal()     to service_role;
