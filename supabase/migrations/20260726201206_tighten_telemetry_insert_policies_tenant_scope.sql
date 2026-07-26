-- Cross-tenant write hardening for the two telemetry tables.
--
-- Before: INSERT policy `insert_own` had WITH CHECK (true), so an
-- authenticated user could supply any tenant_id and have it persist,
-- forging analytics/error rows attributed to OTHER tenants. (The
-- set_tenant_id BEFORE-INSERT trigger only fills tenant_id when it is
-- left NULL, so an explicit foreign value slipped straight through.)
--
-- After: allow the row only when tenant_id is NULL (the normal app path —
-- the trigger then fills it from the caller's JWT) or already equals the
-- caller's own tenant. Foreign tenant_ids are rejected. service_role
-- bypasses RLS and is unaffected; anon still has no INSERT policy at all.
alter policy insert_own on public.analytics_events
  with check (tenant_id is null or tenant_id = public.auth_tenant_id());

alter policy insert_own on public.client_errors
  with check (tenant_id is null or tenant_id = public.auth_tenant_id());
