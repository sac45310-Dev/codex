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
