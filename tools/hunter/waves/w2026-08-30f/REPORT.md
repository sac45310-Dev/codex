# Wave w2026-08-30f — report

Date: 2026-08-30. **40 Haiku 4.5 roster agents in five batches, launched
together** — 5x the per-session guidance in this repo's README, run
deliberately at the user's request.

## Results

- **179 net-new people** — **3 Tier A / 56 Tier B / 120 Tier C**.
- **118 coverage rows**; 23 orgs rostered, 10 exhausted, 2 rejected.
- Running totals: **3,736 people · 1,690 coverage rows · 59 orgs rostered ·
  368 unrostered**. Corpus Tier B share now **25%**.

Biggest Tier B yields: Good Shepherd Maine (6), Hope For The Warriors (5),
Greater Cleveland (5), Akron-Canton (4), Capital Area Food Bank (3),
Operation Homefront (3), Freestore (3).

## The search cap bit, exactly as predicted

The session's ~200-search budget ran out partway through batch 5. **Five agents
returned nothing because they never got to search**: The Bob Woodruff
Foundation, Heart for Africa, Medical Mission of Mercy USA, Wounded Warriors
Family Support, Our Military Kids.

Two consequences were handled explicitly:

1. Those five orgs were set back to **`unrostered`**, not `exhausted`. Marking a
   starved org "exhausted" would permanently retire a target nobody ever looked
   at — the exact error wave w2026-08-29b made.
2. Their agents still emitted `coverage[]` rows for queries they *planned* but
   never ran. **22 such rows were discarded** rather than loaded. Coverage is
   the "never search this again" memory; poisoning it with unexecuted queries
   would silently blind future waves.

This is the concrete cost of running five batches at once: 35 of 40 agents did
real work, 5 burned tokens for nothing. The README's ≤8-agents-per-session
guidance holds — exceeding it trades yield for waste at a predictable ratio.
To go wider, split across sibling sessions with fresh budgets instead.

## Data quality: the ingest normalizer paid for itself

`normalize_person()` made **114 coercions** in this wave alone. The largest
class: agents scoring on a **0–100 scale** (95, 85, 80) instead of the 1–10 tier
bands. Three waves ago that would have been 114 hand-edits — or, worse, 114 bad
rows.

Four things still needed human judgment, which is the right division of labour:

- **Job-posting citations.** Three Tier B records cited a *vacancy listing* as
  proof the person holds the role (Glassdoor, tealhq, a jobs board). A posting
  proves the role exists, not who fills it — dropped to `low` confidence with
  the caveat written into the role field.
- **Unverified "Staff Member".** One record was Tier B on a generic "Staff"
  title with no development evidence — demoted to Tier C.
- **TEAM missionaries.** Three Tier A records cited a *how-to-write-a-support-
  letter article*, not personal giving pages — re-tagged
  `evidence_basis: org_policy`, confidence medium, per the org-policy rule.
- **Networks and divisions.** Feeding Florida, Feeding the Carolinas and
  Midwest Food Bank (Georgia) were correctly identified as member associations
  or a division of a parent rather than addressable orgs. The parent-org filter
  added last wave did its job.

## Outstanding

- 368 orgs unrostered, including the 5 starved ones now correctly back in queue.
- Wounded Warrior Project and Blue Star Families both publish development
  *roles* but no incumbent names — worth a targeted LinkedIn pass rather than
  another general roster agent.

## Post-wave hygiene (no search budget required)

Three organizations existed twice in `hunt_targets`: **Channel One Regional
Food Bank**, **Sage Compassion for Animals**, and **Second Harvest Food Bank of
Northeast Tennessee**. Each pair was one pilot-wave row plus one w2026-08-30a
row that had rediscovered the org under a *different website*.

This matters more than it looks. `org_name` is the join key for
`scout_candidates.meta->>'target_org'`, so a duplicate splits one org's roster
across two rows and leaves `headcount_found` wrong on both — and the assignment
query can dispatch an agent to an org that is already rostered under its twin.

**Merge policy — the pilot row won, not the higher-priority one.** `priority` is
derived, so it recomputes; it is not evidence. The pilot rows carried `notes` and
`faith_orientation`, and their conservative `tier_profile: B` is more likely
correct than the duplicates' `A` — a secular regional food bank has development
staff (Tier B), not support-raised individuals. Keeping the `A` rows would have
preserved exactly the over-tiering the tier-discipline rule exists to prevent.

Where the two rows disagreed on the website, **both domains were kept** in
`notes` with a verify flag rather than silently picking one. `helpingfeedpeople.org`
vs `channeloneregional.org` and `secondharvesttn.org` vs `netfoodbank.org` are
not resolvable without a search, and a confident wrong domain is worse than a
flagged pair. `headcount_est: 45` was folded forward from the discarded row.

**Root cause, fixed in two places** so it cannot recur:

1. `hunt_targets_org_name_key` — unique index on `lower(trim(org_name))`.
2. A `dedup` CTE in `scout_import.py`'s target insert. The existing `NOT EXISTS`
   guard only sees rows committed *before* the statement, so two agents in one
   wave both passed it. `DISTINCT ON` now keeps the richest row of the batch
   (website, then notes, then headcount_est). Verified against the live table
   with a synthetic two-row batch: one row inserted, the richer one.

455 orgs after the merge — 58 rostered, 27 exhausted, 367 unrostered, 3 rejected.
