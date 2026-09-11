-- Promote reviewed hunter findings from person-level scout_candidates into
-- org-level rows in sales.leads.
--
-- Why this exists: approving a scout candidate had no downstream effect. As of
-- 2026-09-10 there were 1,262 approved candidates and 21 with a lead_id, so the
-- review queue was producing decisions that nothing consumed. Organizations are
-- the unit we approach -- individuals are never contacted directly -- so the
-- promotion is an aggregate: one lead per org, carrying its tier headcounts.
--
-- SCORING
--
-- Tier A volume dominates deliberately. Each Tier A person is a personally
-- support-raised worker, i.e. a potential seat, so an org with 100 of them is a
-- materially bigger account than one with 33. An earlier draft capped the Tier A
-- term at 30 people and let the Tier B/C bonuses decide above that, which ranked
-- SEND (100 Tier A) below Ethnos360 (33) -- exactly backwards. Tier B
-- (development staff) and Tier C (leadership) stay small: they are how you get
-- in the door, not what the account is worth.
--
-- Tier A is weighted by confidence rather than counted flat, because the
-- evidence behind a Tier A record varies a lot. A verified personal giving page
-- and an inference from the agency's funding model are both "Tier A", but they
-- are not the same claim. Flat counting let the weaker kind buy identical rank:
-- GEM's 58 include 41 keyed only by opaque numeric giving IDs, and the legacy
-- backfill added 71 people tiered from org policy alone. Weighted, GEM's Tier A
-- reads 41.6 rather than 58 -- the headcount an approach should actually lean on.
--
--   high 1.0 · medium 0.6 · low 0.35 · unrated 0.5
--
-- Both figures go in the notes: the raw count is the size of the population, the
-- weighted one is how much of it is actually evidenced.
--
-- Excluded: do_not_pursue, roster_status 'rejected', and anything named in
-- hunt_negatives (e.g. Campus Outreach Atlanta, a ministry of Perimeter Church
-- rather than an independent buyer -- its people are kept, the org is not a lead).

-- Shared shape for all three statements below.
--   agg  : per-org tier headcounts, raw and confidence-weighted
--   j    : joined to hunt_targets, exclusions applied, score computed

-- ---------------------------------------------------------------------------
-- 1. Update leads that already exist for a hunted org.
-- ---------------------------------------------------------------------------
WITH agg AS (
  SELECT trim(meta->>'target_org') AS org,
         count(*) FILTER (WHERE meta->>'tier'='A') AS a,
         sum(CASE WHEN meta->>'tier'='A' THEN
               CASE meta->>'confidence' WHEN 'high' THEN 1.0 WHEN 'medium' THEN 0.6
                                        WHEN 'low' THEN 0.35 ELSE 0.5 END
             ELSE 0 END) AS a_wt,
         count(*) FILTER (WHERE meta->>'tier'='B') AS b,
         count(*) FILTER (WHERE meta->>'tier'='C') AS c,
         count(*) AS total
  FROM sales.scout_candidates
  WHERE source_query LIKE 'hunter:%' AND status='approved'
    AND meta->>'target_org' IS NOT NULL
  GROUP BY 1),
j AS (
  SELECT agg.*, t.website,
         greatest(0, least(100,
             least(80, floor(agg.a_wt*0.8)) + least(8, agg.b*2) + least(4, agg.c)
           + CASE WHEN t.website IS NOT NULL THEN 8 ELSE 0 END
           - CASE WHEN agg.org ~* '\y(food ?bank|feeding|food pantry|food network)\y'
                  THEN 30 ELSE 0 END))::int AS score
  FROM agg
  LEFT JOIN sales.hunt_targets t ON lower(trim(t.org_name)) = lower(agg.org)
  WHERE NOT coalesce(t.do_not_pursue,false)
    AND coalesce(t.roster_status,'') <> 'rejected'
    AND NOT EXISTS (SELECT 1 FROM sales.hunt_negatives n
                    WHERE lower(trim(n.name)) = lower(agg.org)))
UPDATE sales.leads l
SET score = j.score,
    website = coalesce(l.website, j.website),
    notes = 'Hunter headcount: Tier A (support-raised) '||j.a
            ||' raw / '||round(j.a_wt,1)||' evidence-weighted · Tier B (development staff) '||j.b
            ||' · Tier C (leadership) '||j.c
            ||' · '||j.total||' cited records. Updated '||current_date,
    updated_at = now()
FROM j
WHERE lower(trim(l.org_name)) = lower(j.org);

-- ---------------------------------------------------------------------------
-- 2. Insert leads for hunted orgs that do not have one yet.
-- ---------------------------------------------------------------------------
WITH agg AS (
  SELECT trim(meta->>'target_org') AS org,
         count(*) FILTER (WHERE meta->>'tier'='A') AS a,
         sum(CASE WHEN meta->>'tier'='A' THEN
               CASE meta->>'confidence' WHEN 'high' THEN 1.0 WHEN 'medium' THEN 0.6
                                        WHEN 'low' THEN 0.35 ELSE 0.5 END
             ELSE 0 END) AS a_wt,
         count(*) FILTER (WHERE meta->>'tier'='B') AS b,
         count(*) FILTER (WHERE meta->>'tier'='C') AS c,
         count(*) AS total
  FROM sales.scout_candidates
  WHERE source_query LIKE 'hunter:%' AND status='approved'
    AND meta->>'target_org' IS NOT NULL
  GROUP BY 1),
j AS (
  SELECT agg.*, t.website, t.org_type AS ht_type,
         greatest(0, least(100,
             least(80, floor(agg.a_wt*0.8)) + least(8, agg.b*2) + least(4, agg.c)
           + CASE WHEN t.website IS NOT NULL THEN 8 ELSE 0 END
           - CASE WHEN agg.org ~* '\y(food ?bank|feeding|food pantry|food network)\y'
                  THEN 30 ELSE 0 END))::int AS score
  FROM agg
  LEFT JOIN sales.hunt_targets t ON lower(trim(t.org_name)) = lower(agg.org)
  WHERE NOT coalesce(t.do_not_pursue,false)
    AND coalesce(t.roster_status,'') <> 'rejected'
    AND NOT EXISTS (SELECT 1 FROM sales.hunt_negatives n
                    WHERE lower(trim(n.name)) = lower(agg.org)))
INSERT INTO sales.leads (org_name, org_type, website, source, status, score, notes)
SELECT j.org,
       -- leads.org_type check constraint accepts only these values
       CASE j.ht_type
         WHEN 'agency' THEN 'organization' WHEN 'mission_board' THEN 'organization'
         WHEN 'network' THEN 'organization' WHEN 'parachurch' THEN 'ministry'
         WHEN 'ministry' THEN 'ministry'    WHEN 'nonprofit' THEN 'nonprofit'
         WHEN 'church' THEN 'church'        ELSE 'organization' END,
       j.website, 'scrape', 'new', j.score,
       'Hunter headcount: Tier A (support-raised) '||j.a
       ||' raw / '||round(j.a_wt,1)||' evidence-weighted · Tier B (development staff) '||j.b
       ||' · Tier C (leadership) '||j.c
       ||' · '||j.total||' cited records. Created '||current_date
FROM j
WHERE NOT EXISTS (SELECT 1 FROM sales.leads l
                  WHERE lower(trim(l.org_name)) = lower(j.org));

-- ---------------------------------------------------------------------------
-- 3. Link each approved person back to its org's lead.
-- ---------------------------------------------------------------------------
UPDATE sales.scout_candidates s
SET lead_id = l.id
FROM sales.leads l
WHERE s.source_query LIKE 'hunter:%' AND s.status='approved'
  AND s.meta->>'target_org' IS NOT NULL
  AND lower(trim(l.org_name)) = lower(trim(s.meta->>'target_org'))
  AND s.lead_id IS DISTINCT FROM l.id;
