-- Email-extraction worklist.
--
-- Emits one row per approved person who is live as a lead, already has a
-- per-person page stored, and has no email on any of their contact rows.
--
-- Usage: set :agency to the normalised agency key (see the keys listed in
-- README.md), or leave it as '%' to emit every agency at once.
--   psql "$DATABASE_URL" -v agency="focus" -f worklist.sql --csv -o worklist.csv
--
-- The join to sales.contacts is keyed on lead_id AND scout_candidate_id.
-- Keying on either alone under-reports: only 2,327 of 7,302 contact rows
-- carry scout_candidate_id, and contacts written by sales_enrich_write do
-- not carry lead_id. Both keys are required to answer "do we already hold
-- an email for this person".

\set ON_ERROR_STOP on

with person as (
  select
    c.id                                        as scout_candidate_id,
    c.lead_id,
    c.org_name                                  as person_name,
    coalesce(
      nullif(btrim(c.meta->>'target_org'), ''),
      c.org_name
    )                                           as agency,
    coalesce(
      nullif(c.source_url, ''),
      c.meta->>'evidence_url',
      c.meta->>'donation_page'
    )                                           as url
  from sales.scout_candidates c
  where c.org_type in ('individual', 'Individual', 'missionary')
    and c.status = 'approved'
    and c.lead_id is not null
),
scored as (
  select
    p.*,
    btrim(regexp_replace(
      lower(translate(p.agency, '.''-"/,&', '      ')),
      '\s+', ' ', 'g')) as agency_key,
    exists (
      select 1 from sales.contacts ct
      where (ct.lead_id = p.lead_id
             or ct.scout_candidate_id = p.scout_candidate_id)
        and coalesce(ct.email, '') <> ''
    ) as has_email
  from person p
)
select
  scout_candidate_id,
  lead_id,
  agency_key,
  person_name,
  url
from scored
where not has_email
  and url ~* '^https?://'
  and (:'agency' = '%' or agency_key = :'agency')
order by agency_key, person_name;
