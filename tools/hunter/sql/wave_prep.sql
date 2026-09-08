-- Wave prep exports. Run each section via execute_sql before a wave;
-- save results as JSON for skip_list_generator.py and assignment building.

-- 1. Existing people + orgs (feed to skip_list_generator.py generate-from-json)
SELECT org_name, website FROM sales.scout_candidates WHERE status <> 'rejected'
UNION
SELECT org_name, website FROM sales.leads;

-- 2. Do-not-crawl domains: covered ground that yielded nothing, < 90 days old
SELECT DISTINCT domain
FROM sales.hunt_coverage
WHERE kind = 'url'
  AND outcome IN ('no_people','dead','offtopic')
  AND visited_at > now() - interval '90 days'
  AND domain IS NOT NULL
ORDER BY domain;

-- 3. Covered queries (orchestrator drops duplicate assignments before dispatch)
SELECT value FROM sales.hunt_coverage WHERE kind = 'query' ORDER BY value;

-- 4. Roster assignments: next unrostered targets, highest priority first.
-- do_not_pursue orgs stay cataloged but never receive roster budget.
-- `priority` is maintained by section 4b below; recompute it before a wave.
SELECT t.id, t.org_name, t.website, t.org_type, t.size_estimate, t.tier_profile,
       t.faith_orientation, t.crm_incumbent, t.priority,
       t.headcount_found AS known_people_count
FROM sales.hunt_targets t
WHERE t.roster_status = 'unrostered'
  AND NOT coalesce(t.do_not_pursue, false)
ORDER BY t.priority DESC NULLS LAST, t.headcount_est DESC NULLS LAST, t.id
LIMIT 40;

-- 4b. Recompute priority. REVISED 2026-08-30 against observed yield from
-- waves w2026-08-29b through w2026-08-30d (44 orgs worked).
--
-- What the data showed:
--   * org_type is the strongest predictor. Mean people found per org:
--       parachurch 15.8 · nonprofit 12.5 · agency 11.7 · ministry 3.1
--     "ministry" here is dominated by individual YWAM bases, which do not
--     publish staff rosters — 4 of 5 attempts returned nothing findable by
--     search. They are penalised, not excluded: a base with a public
--     staff-profile page (YWAM San Diego/Baja) still works.
--   * headcount_est was NOT predictive and has been dropped from the formula.
--     Mercy Ships (est. 1600) yielded 13; Ethnos360 (no estimate) yielded 40.
--     Agent-guessed org size measures the org, not what it publishes, and it
--     was pulling the queue toward big unreachable targets.
--   * A missing website is a real handicap — there is nothing to search.
UPDATE sales.hunt_targets SET priority = greatest(0, least(100,
-- Priority v3, rebuilt 2026-09-08 on the team triage rather than on yield stats.
--
-- What the triage showed: every Tier-A-rich agency was approved, including ones
-- with no development contact at all (Ethnos360 33 Tier A, World Gospel 25,
-- Cru 12). All five orgs passed over had ZERO Tier A -- and four of them had
-- fully sourced development staff. Support-raised volume converts; a lone
-- development director does not. v2 had this backwards.
--
-- Food banks deprioritized at the user's direction: board-heavy rosters, no
-- support-raised base, high search cost per usable contact.
--
-- backfill:approved rows keep a neutral base because their org_type is an
-- import default, not a classification -- scoring it as 'ministry' buried
-- Operation Mobilization and Cross International.
    CASE
      WHEN discovered_by = 'backfill:approved' THEN 14
      ELSE CASE org_type
        WHEN 'agency' THEN 34 WHEN 'mission_board' THEN 34
        WHEN 'parachurch' THEN 28
        WHEN 'nonprofit' THEN 16
        WHEN 'network' THEN 4 WHEN 'ministry' THEN 12 ELSE 14 END
    END
  + CASE WHEN tier_profile IN ('A','AB') THEN 30 ELSE 0 END
  + least(30, tier_a_found * 2)
  + CASE WHEN website IS NOT NULL AND website NOT ILIKE '%usachurches.org%' THEN 12 ELSE 0 END
  + CASE WHEN size_estimate IN ('mid','small') THEN 10
         WHEN size_estimate = 'large' THEN 8
         WHEN size_estimate = 'micro' THEN 2 ELSE 0 END
  - CASE WHEN org_name ~* '\y(food ?bank|feeding|food network|food pantry)\y' THEN 30 ELSE 0 END
));

-- Refresh tier_a_found before recomputing priority; it is the strongest term.
UPDATE sales.hunt_targets t SET tier_a_found = coalesce(c.n, 0)
FROM (SELECT lower(trim(meta->>'target_org')) AS k, count(*) AS n
      FROM sales.scout_candidates
      WHERE meta->>'tier' = 'A' AND status <> 'rejected' GROUP BY 1) c
WHERE lower(trim(t.org_name)) = c.k AND t.tier_a_found IS DISTINCT FROM c.n;

-- 5. Known negatives (context for prompt building; keeps agents off dead ends)
SELECT entity_kind, name, reason_code FROM sales.hunt_negatives ORDER BY name;

-- 6b. Feedback loop: approval rate by hunting ground. High-approval source
-- queries/niches get MORE assignments next wave; high-reject ones get their
-- pattern added to hunt_negatives and their niche deprioritized.
SELECT split_part(source_query, ':', 1) AS hunting_ground,
       count(*) AS total,
       count(*) FILTER (WHERE status = 'approved') AS approved,
       count(*) FILTER (WHERE status = 'rejected') AS rejected,
       round(100.0 * count(*) FILTER (WHERE status = 'approved')
             / nullif(count(*) FILTER (WHERE status IN ('approved','rejected','skipped')), 0)) AS approval_pct
FROM sales.scout_candidates
GROUP BY 1
HAVING count(*) >= 10
ORDER BY approval_pct DESC NULLS LAST, total DESC;

-- 6c. Feedback loop: reject-reason trends. A reason code that keeps growing
-- means agents are still bringing in that pattern — tighten the prompt rule.
SELECT reason_code, count(*) AS total,
       count(*) FILTER (WHERE created_at > now() - interval '30 days') AS last_30d
FROM sales.hunt_negatives
GROUP BY 1 ORDER BY total DESC;

-- 6. Post-wave: org-pitch headcount report (pursuable accounts only)
SELECT t.org_name, t.website, t.faith_orientation, t.crm_incumbent,
       t.roster_status, t.headcount_found,
       count(s.*) FILTER (WHERE (s.meta->>'tier') = 'A') AS tier_a_support_raised,
       count(s.*) FILTER (WHERE (s.meta->>'tier') = 'B') AS tier_b_dev_staff,
       count(s.*) FILTER (WHERE (s.meta->>'tier') = 'C') AS tier_c_influencers
FROM sales.hunt_targets t
LEFT JOIN sales.scout_candidates s ON lower(s.meta->>'target_org') = lower(t.org_name)
WHERE NOT t.do_not_pursue
GROUP BY 1,2,3,4,5,6
ORDER BY t.headcount_found DESC, t.org_name;
