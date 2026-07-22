-- Export existing DonorSend contacts (name + website) so hunters can be told
-- to skip them. Run via the Supabase execute_sql MCP tool, save the JSON
-- result to a file, then feed it to:
--   python3 scout_import.py snapshot existing.json
--
-- Unions the scout review queue and the live pipeline; both are things a
-- hunter re-finding a contact would be duplicating.
select org_name, website from sales.scout_candidates
union
select org_name, website from sales.leads;
