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

-- 4b. Recompute priority. Weights the two things that decide roster payoff:
-- support-raised orgs (every staffer is a prospective user) and how many
-- people are actually there, with a nudge toward mid/small orgs that are
-- realistic switchers and away from targets with no website to search.
UPDATE sales.hunt_targets SET priority =
  (CASE WHEN tier_profile IN ('A','AB') THEN 40 ELSE 0 END
   + CASE WHEN headcount_est >= 200 THEN 30 WHEN headcount_est >= 50 THEN 22
          WHEN headcount_est >= 15 THEN 14 WHEN headcount_est IS NOT NULL THEN 6
          ELSE 0 END
   + CASE WHEN size_estimate IN ('mid','small') THEN 12
          WHEN size_estimate = 'large' THEN 6
          WHEN size_estimate = 'micro' THEN 3 ELSE 0 END
   + CASE WHEN website IS NOT NULL THEN 8 ELSE 0 END);

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
