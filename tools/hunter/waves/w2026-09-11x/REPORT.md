# Wave w2026-09-11x — budget-limited continuations

**4 agents, 72 searches. 120 people loaded. Yield 1.67/query** — above the
1.3–1.4 retirement line, but only because one slice carried it.

## The wave was a test of a rule, and the rule half-held

Wave u produced the rule: *continue only where the first pass was cut short by
BUDGET, not by the INDEX.* Targets were picked by dividing people found by
queries actually spent, read out of `hunt_coverage`.

| agency | earlier rate | queries then | **new here** | **rate now** |
|---|---|---|---|---|
| **Every Nation** | 4.4/q | 9 | **78** | **4.3** ✅ |
| Baptist Missions to Forgotten Peoples | 5.5/q | 11 | 20 | 1.1 |
| Baptist International Outreach | 2.8/q | 6 | 15 | 0.83 |
| Baptist Church Planters | 3.2/q | 12 | 7 | 0.39 |

**Every Nation held its rate exactly** — 4.4 before, 4.3 now, 78 new people.
The other three decayed to at or below the retirement line despite having the
same "budget-limited" signature.

## The refinement: query count alone is not the predictor

Every Nation differs from the other three in one way that matters: **a known
roster size far larger than what was held.** The agency states 324+
cross-cultural missionaries plus campus staff across 1,405 campuses, and only
40 were held — about 12% covered. BMFP, BIO and BCP are small independent
Baptist boards where 61, 17 and 38 people may already be most of the roster.

So the rule becomes:

> Continue when the first pass was cut short by budget **and** a stated or
> credible roster size is far larger than what is held. A low query count on a
> small agency just means the agency is small.

That is testable from the database — `headcount_found` against
`headcount_est` — and it is cheaper than discovering it by spending a slice.

## Ingest corrections

**BIO's file needed the most work of any this session.** Eleven of 22 records
cited the bare `biomissions.org/missionaries/` **directory** rather than a
per-person page, and two of those were graded `high` with
`evidence_basis: personal_page`. All were downgraded to `medium` /
`staff_directory`. One record used confidence `low`, which is not a value in
this pipeline, and was regraded. A WordPress tag archive was downgraded to
`medium` per the wave-r Bredeweg precedent.

Three BIO records were withheld: two Tier B entries whose citations were an
article (`/dr-emmett-manley-winning-the-war-with-worry/`) and an author archive
(`/author/gdykes/`) with no field-missionary confirmation, and one
article-titled page with no current-activity statement.

**BCP's file was clean** — 19 records, all real per-person URLs across both
surfaces, the opaque numeric slug (`/wpfc_person/3578/`) correctly graded
`medium`, and the retiree trap caught by the agent itself: Steve Little,
retired BCP president, routed to `needs_review` rather than emitted.

## Two things worth keeping

**Exclusion lists can hide real people.** BMFP returned Stephen and Victoria
Lyons as new, despite "Lyons" being on the exclusion list I supplied — there
are two unrelated Lyons families at that agency. Aggressive exclusion sweeps
trade recall for reach, and on a small roster that trade is bad.

**The exclusion-operator limit was independently confirmed again.** Both the
BMFP and BCP agents reported unprompted that negative terms worked for the
first few queries and then stopped filtering, with excluded surnames
reappearing. That is the documented ~10–12 term ceiling, now observed across
four separate waves.
