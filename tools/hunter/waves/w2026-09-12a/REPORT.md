# Wave w2026-09-12a — SIL International

**3 people loaded. 47 searches. 0.06 new-people-per-query.**
The retirement line is 1.3–1.4. `roster_status` set to `exhausted`.

| agent | axis | searches | people | verdict |
|---|---|---|---|---|
| sil-a | Africa and Asia | 18 | 2 (both re-finds of the probe's seeds) | exhausted |
| sil-b | Americas, Eurasia, Pacific | 14 | 3 (one new: Terry Dehart) | exhausted |
| sil-c | roles and disciplines | 12 | 2 (both re-finds) | exhausted |
| orchestrator | probe + vanity-slug follow-up | 9 | 2 seeds found, 0 further | — |

All three agents stopped early on the three-consecutive-nothing rule. All three
returned `exhausted` independently.

## A counting correction

The agents each reported ~0 "new" people, measuring against the two seeds the
brief handed them. Measured against the **CRM**, which is what the metric is
for, all three names were absent: Oliver Dixon, Saul Delgado and Terry Dehart
are all net-new. So the wave loaded 3, not 1. That does not rescue it — 3 from
47 searches is 0.06/query, the worst of any wave run — but the number in the
table should be the honest one.

## Why both axes died, which is the durable finding

**A SIL personal support page carries the person's name in its indexed text and
nothing else.** No country, no field location, no role. The title is literally
`Donate to <Name> Support`.

That single fact kills both axes at once:

- **Geography** (agents A and B, 32 searches). Every country and region term
  returned the same fixed set of institutional pages regardless of which place
  was in the query — SIL Togo-Benin General Fund, CTNA SIL Nigeria, Eastern
  Congo Group Projects, SIL Bangladesh, Health & Language Initiative. Several
  queries fell off the domain entirely into UNHCR and GlobalGiving noise, which
  means the engine found nothing on-domain matching the country at all.
  **Wave t's geographic split worked on Wycliffe because Wycliffe puts the
  country in the indexed snippet. SIL does not.**
- **Roles** (agent C, 12 searches). Worse than useless: role terms are the
  *body text of the software campaigns*, so translator, linguist, literacy
  specialist and the rest rank Paratext, FieldWorks, WSTech, App Builders,
  Keyman and Bloom **above** the people. This is the worst axis on record —
  wave u's language-and-people-group slice on Wycliffe managed 2 new from 18;
  this managed 0 from 12.

## Two structural facts worth keeping

**The numeric ID space cannot be walked.** `give/484793` is *SIL Bangladesh*, a
fund, and it sits numerically between `give/484678` (Dixon) and `give/500598`
(Delgado). People and funds share one ID sequence, so enumeration by ID would
return mostly funds and could not be validated without fetching.

**My brief was wrong about vanity slugs, and agent B caught it.** The brief's
table said `give.sil.org/<vanity-slug>` is "never a person", generalised from
`/paratext`, `/LangTech` and `/archives`. But `give.sil.org/Terry-Dehart` and
`give.sil.org/give/533493` are the same page. **A `Firstname-Lastname` vanity
slug is a person** — and unlike the numeric form it *would* tie the URL to the
name, which is worth a `high` confidence grade rather than `medium`. I probed
that alias shape directly with three further searches and it surfaced no
additional people, so it does not reopen the agency; it corrects the rule.

## The hypothesis the wave was built to test

The brief set out two readings of a thin probe. All three agents converged on
the second: **SIL members raise support through their sending organisation, not
through SIL.** The whole indexed person population of `give.sil.org` is three
names, while every other SIL person in the database is filed under *Wycliffe* —
Esther Morrow, "Cartographer, SIL Americas", at
`wycliffe.org/partner/esthermorrow`; Jaime Ayala directing SIL Americas South
on a Wycliffe bio; Emily Roth filed "Wycliffe/SIL".

SIL is not a new agency. It is a thin second view of a roster wave u already
showed to be search-exhausted.

**The bound on that claim, which all three agents stated unprompted and
correctly:** page fetching is blocked, so "few member pages exist" and "member
pages exist but carry `noindex`" are indistinguishable from search evidence.
What the wave does establish is convergence — three agents, three different
axes, one answer.

## Protections

Zero violations across all three agents. No `needs_review` records: no title in
any result gave initials only, a first name only, or a codename, and none
carried a closed date range. Every emitted record is `medium` confidence,
`personal_page`, Tier A, `fit_score` 7, exactly as the unconditional rules
specified — the wave z pattern held again.

## What this says about picking the next target

The audit ranked SIL first among 28 unworked agencies on size and adjacency to
the best-performing wave. Both signals were real and both were wrong, because
neither measures **whether the agency funds its people through its own domain**.
A large roster reachable only through a sending organisation is not a target.

That test is cheap and belongs in front of the surface probe:
*does this agency's own giving domain carry more people than programmes?* Six
searches would have answered it here before three agents were dispatched.
