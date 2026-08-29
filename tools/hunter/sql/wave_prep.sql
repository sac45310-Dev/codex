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

-- 4. Roster assignments: next unrostered targets by priority
SELECT t.id, t.org_name, t.website, t.org_type, t.size_estimate, t.tier_profile,
       t.headcount_found AS known_people_count
FROM sales.hunt_targets t
WHERE t.roster_status = 'unrostered'
ORDER BY t.priority, t.headcount_found DESC, t.id
LIMIT 40;

-- 5. Known negatives (context for prompt building; keeps agents off dead ends)
SELECT entity_kind, name, reason_code FROM sales.hunt_negatives ORDER BY name;

-- 6. Post-wave: org-pitch headcount report
SELECT t.org_name, t.website, t.roster_status, t.headcount_found,
       count(s.*) FILTER (WHERE (s.meta->>'tier') = 'A') AS tier_a,
       count(s.*) FILTER (WHERE (s.meta->>'tier') = 'B') AS tier_b
FROM sales.hunt_targets t
LEFT JOIN sales.scout_candidates s ON lower(s.meta->>'target_org') = lower(t.org_name)
GROUP BY 1,2,3,4
ORDER BY t.headcount_found DESC, t.org_name;
