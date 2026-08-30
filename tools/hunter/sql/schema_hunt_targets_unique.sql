-- Applied 2026-08-30 as migration `hunt_targets_unique_org_name`.
--
-- Three duplicate org rows accumulated (Channel One Regional Food Bank,
-- Sage Compassion for Animals, Second Harvest Food Bank of Northeast
-- Tennessee) because two agents in the SAME wave returned the same org under
-- different websites. The NOT EXISTS guard in the generated wave_targets.sql
-- only sees rows committed before the statement, so both passed.
--
-- org_name is the join key for sales.scout_candidates.meta->>'target_org',
-- so a duplicate splits one org's roster across two rows and makes
-- headcount_found wrong on both. The index makes that unrepresentable; the
-- matching in-batch fix is the `dedup` CTE in scout_import.py.

create unique index if not exists hunt_targets_org_name_key
  on sales.hunt_targets (lower(trim(org_name)));
