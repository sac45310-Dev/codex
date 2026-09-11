-- Export existing DonorSend contacts so hunters can be told to skip them.
-- Run via the Supabase execute_sql MCP tool, save the JSON result to a file,
-- then feed it to:
--   python3 scout_import.py snapshot existing.json
--
-- Unions the scout review queue and the live pipeline; both are things a
-- hunter re-finding a contact would be duplicating.
--
-- Uses coalesce(website, source_url): for PERSON records website is null and
-- the identifying URL lives in source_url. Selecting website alone dropped 822
-- records' URLs -- including every personal giving page, which is the single
-- most identifying datum a person record has.
select org_name, coalesce(website, source_url) as website from sales.scout_candidates
union
select org_name, website from sales.leads;
