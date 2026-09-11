-- Derive evidence_basis for Tier A rows that never carried one.
--
-- 187 approved Tier A records predated the evidence_basis convention. They were
-- weighted 1.0 in the org score purely because their confidence said 'high',
-- which made them the weakest link in the ranking.
--
-- The tempting fix was a second scoring axis that discounts rows with no basis.
-- That is wrong twice over:
--
--   1. The 187 are not uniformly weak. Testing each against its OWN citation --
--      does the cited URL name the person, and is it a giving/profile page --
--      splits them four ways, and 67 turn out to be exactly as well evidenced
--      as the labelled personal_page rows (which self-verify at 90%). A blanket
--      discount would punish those for a missing label.
--
--   2. confidence and evidence_basis are not independent axes. They are two
--      encodings of the same judgement -- there is no high/org_policy row in the
--      system, because confidence was always set FROM the evidence quality.
--      Multiplying them would discount the same fact twice.
--
-- So: derive the missing metadata instead of weighting its absence, and let the
-- single confidence axis carry it. No new evidence is gathered here; this only
-- reads what each record already cites.
--
--   names the person + giving/profile URL -> personal_page   / high   (1.00)
--   names the person, other URL           -> staff_directory / medium (0.60)
--   giving URL, does not name the person  -> org_policy      / medium (0.60)
--   neither                               -> unverified      / low    (0.35)

WITH p AS (
  SELECT id, source_url,
    lower(split_part(regexp_replace(source_url,'/+$',''),'/',-1)) AS slug,
    lower(split_part(org_name,' ',1)) AS firstn,
    lower(split_part(org_name,' ', array_length(string_to_array(org_name,' '),1))) AS lastn
  FROM sales.scout_candidates
  WHERE source_query LIKE 'hunter:%' AND status='approved'
    AND meta->>'tier'='A' AND meta->>'evidence_basis' IS NULL),
c AS (
  SELECT id,
    (slug IS NOT NULL AND slug !~ '^[0-9]+$'
     AND (position(lastn IN slug)>0 OR position(firstn IN slug)>0)) AS named,
    (source_url ~* '(give|donate|support|partner|missionar|staff|profile)') AS giving
  FROM p),
v AS (
  SELECT id,
    CASE WHEN named AND giving THEN 'personal_page'
         WHEN named THEN 'staff_directory'
         WHEN giving THEN 'org_policy'
         ELSE 'unverified' END AS basis,
    CASE WHEN named AND giving THEN 'high'
         WHEN named OR giving THEN 'medium'
         ELSE 'low' END AS conf
  FROM c)
UPDATE sales.scout_candidates s
SET meta = s.meta || jsonb_build_object(
      'evidence_basis', v.basis, 'confidence', v.conf,
      'basis_derived','mechanical backfill: evidence_basis inferred from the record''s own citation. No new evidence gathered.')
FROM v WHERE s.id = v.id;

-- Then re-run promote_orgs_to_leads.sql to push the new weights into the scores.
