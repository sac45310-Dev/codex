-- Resolve legacy "Name (Agency)" scout rows onto canonical hunt_targets.
--
-- 140 approved people were invisible to every org rollup because they predate
-- the target_org convention: the agency was only ever a parenthetical in
-- org_name, usually an acronym (BIMI, FBMI, WWNTBM, CMML, IBFI, MWBM).
--
-- The expansions here were NOT guessed. Each legacy row carries a source_url,
-- and the domain in that citation identifies the agency unambiguously
-- (bimi.org, fbmi.org, wwntbm.com, cmml.us, ibfi.us, mwbm.org). The full names
-- were then confirmed against each agency's own site before being written here.
--
-- Only agencies with 2+ people get a canonical target. The 27 singletons keep
-- meta.legacy_agency and stay unmapped: one person does not make an account
-- worth opening, and inventing an org record for each would just add noise.

INSERT INTO sales.hunt_targets (org_name, org_type, website, faith_orientation,
       tier_profile, roster_status, discovered_by, notes, tier_a_found, do_not_pursue)
SELECT x.name, x.otype, x.site, 'christian', 'A', 'unrostered', 'backfill:legacy-acronym',
       'Canonical name for legacy label "'||x.acr||'"; expansion confirmed on the agency''s own site '||x.site,
       0, false
FROM (VALUES
 ('BIMI','Baptist International Missions, Inc.','agency','bimi.org'),
 ('FBMI','Fundamental Baptist Missions International','agency','fbmi.org'),
 ('WWNTBM','World Wide New Testament Baptist Missions','agency','wwntbm.com'),
 ('CMML','Christian Missions in Many Lands, Inc.','agency','cmml.us'),
 ('IBFI','Independent Baptist Fellowship International','agency','ibfi.us'),
 ('MWBM','Macedonia World Baptist Missions, Inc.','agency','mwbm.org'),
 ('Mission to the World','Mission to the World','agency','mtw.org'),
 ('Converge','Converge','agency','converge.org'),
 ('WorldVenture','WorldVenture','agency','worldventure.com'),
 ('Family Missions Company','Family Missions Company','agency','familymissionscompany.com'),
 ('YWAM Lancaster','YWAM Lancaster','ministry','ywamlancaster.com')
) AS x(acr,name,otype,site)
WHERE NOT EXISTS (SELECT 1 FROM sales.hunt_targets t
                  WHERE lower(trim(t.org_name)) = lower(x.name));

-- Point the legacy rows at the canonical names. Wycliffe / TEAM / SIM already
-- had targets, so they map onto the existing rows rather than creating dupes.
UPDATE sales.scout_candidates s
SET meta = s.meta || jsonb_build_object('target_org', m.canonical,
      'acronym_resolved_by','domain in the record''s own citation, expansion confirmed on the agency site')
FROM (VALUES
 ('BIMI','Baptist International Missions, Inc.'),
 ('FBMI','Fundamental Baptist Missions International'),
 ('WWNTBM','World Wide New Testament Baptist Missions'),
 ('CMML','Christian Missions in Many Lands, Inc.'),
 ('IBFI','Independent Baptist Fellowship International'),
 ('MWBM','Macedonia World Baptist Missions, Inc.'),
 ('Mission to the World','Mission to the World'),
 ('Converge','Converge'),
 ('WorldVenture','WorldVenture'),
 ('Family Missions Company','Family Missions Company'),
 ('YWAM Lancaster','YWAM Lancaster'),
 ('Wycliffe','Wycliffe Bible Translators USA'),
 ('TEAM','TEAM - The Evangelical Alliance Mission'),
 ('SIM','SIM USA')
) AS m(acr,canonical)
WHERE s.source_query LIKE 'hunter:%'
  AND s.meta->>'target_org' IS NULL
  AND lower(trim(s.meta->>'legacy_agency')) = lower(m.acr);

-- Tier, assigned only where the row's OWN evidence supports it. These agencies
-- are faith missions where personal support-raising is the universal funding
-- model, so it would be easy to stamp Tier A on all 140 -- but that infers the
-- individual from the org, which is the inversion this pipeline exists to avoid.
-- 69 rows earn Tier A on their own text; the remaining 71 stay untiered.

-- A: the row cites a giving/support page of its own.
UPDATE sales.scout_candidates s
SET meta = s.meta || jsonb_build_object('tier','A','role','Missionary',
      'evidence_basis','personal_page','confidence','high',
      'review_note','tier assigned from the record''s own cited giving/support page')
WHERE s.source_query LIKE 'hunter:%' AND s.meta->>'legacy_agency' IS NOT NULL
  AND s.meta->>'tier' IS NULL
  AND s.source_url ~* 'give|donate|support|partner';

-- B: the row's own summary states deputation / support-raising / prayer letters.
UPDATE sales.scout_candidates s
SET meta = s.meta || jsonb_build_object('tier','A','role','Missionary',
      'evidence_basis','org_policy','confidence','medium',
      'review_note','tier assigned: the record''s own text states deputation or personal support-raising; no per-person giving page cited')
WHERE s.source_query LIKE 'hunter:%' AND s.meta->>'legacy_agency' IS NOT NULL
  AND s.meta->>'tier' IS NULL
  AND coalesce(s.summary,'')||' '||coalesce(s.fit_reason,'')
      ~* '\y(deputation|support-rais|support rais|prayer letter|giving page|partner with|donate|support team)\y';

-- Then re-run promote_orgs_to_leads.sql to fold these into the org headcounts.
