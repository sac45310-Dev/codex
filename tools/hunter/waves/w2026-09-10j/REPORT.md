# Wave w2026-09-10j — report

Four agents, 18 searches each (72), plus 2 orchestrator verification searches.
Both targets were below the retirement line going in, so the whole budget went
to two surfaces no prior wave had touched.

## Loaded

**46 people.** 98 emitted → 9 cross-agent dupes → 43 already held.

| org | new | new/query | verdict |
|---|---|---|---|
| Reformed University Fellowship | 27 | 0.75 | marginal |
| Coalition for Christian Outreach | 19 | 0.53 | done |
| **wave** | **46** | **0.64** | |

CCO now 119 held, RUF 222.

I set the close-out threshold at ~0.7 before dispatching. The wave came in at
0.64, so **both orgs are closed out.** RUF's 0.75 is fractionally above it and
CCO's 0.53 clearly below; neither justifies a further pass when untouched
agencies have produced 3.7–5.0/query from a standing start.

## The new RUF surface was real, and it corrected an earlier finding of mine

Waves g–i recorded that "ruf.org has no per-person pages" and moved to
givetoruf.org. True but incomplete: **ruf.org carries per-campus ministry
pages with staff bios**, and nobody had searched them. Two properties make it
a distinct seam rather than a re-find:

- It returns **multiple people per page** — Wake Forest 3, Wisconsin-Madison
  2, Milwaukee 2, Rice 2, Vanderbilt 2, Tennessee 2, Kansas State 2 — where a
  givetoruf.org campus code returned one.
- Most of these people have **no personal giving page at all**. Campus staff
  and interns who never appear on givetoruf.org. 27 of the 37 RUF records were
  new despite three prior waves on the org.

It still only reached 0.75/query, because the pages are expensive to mine:
see below.

## What limited the RUF surface: partial names

These bios introduce people by first name — "Emily spent her childhood in
Iowa", "Grace began serving in 2024". A first-name-only record is a hard-rule
violation, so both agents were told to route them to `needs_review`. They did:
**50 partial-name findings across the two agents** (18 and 32) against 37
records emitted. `ruf-ministry-a` measured the ratio at roughly 2:1 partial to
full.

That is the surface working as designed rather than a defect — the rule is
what stopped 50 unusable half-records entering the database — but it caps
what the surface can yield.

## CCO: the last untested angle, and it did not rescue the target

`cco-national` tested the correction from last wave, that CCO is national
rather than PA/Ohio/mid-Atlantic. It returned 0.33/query. `cco-index`
enumerated the campus list properly and did better, but the combined 0.53 is
no improvement on the 0.28 that already put CCO below the line.

The negative space is worth recording: **San Jose State, Seattle, Portland,
Denver, Minnesota, Nashville, Atlanta, Chicago, Muhlenberg, Dickinson and
Widener all returned no CCO staff.** CCO's national presence is real but
thin — one or two people per site, against clusters in western Pennsylvania.

`cco-index` did deliver something durable: **16 campuses we did not know CCO
served** — PennWest California, Fresno State, Butler, Central Florida,
Gettysburg, Penn, Carnegie Mellon, Richmond, Northern Virginia CC, Montreat,
VCU, St. John's, Florida, Valencia, Malone, Ohio Wesleyan. That list is in its
`needs_review` and is the reason CCO is being closed rather than abandoned:
if the org is ever revisited, the campus list is now known.

## Grading held

The reason-carrying grading rule kept working. Every one of the 37 RUF
ministry-page records came back `medium` / `staff_directory` without
correction, and both CCO agents graded `/staff/<slug>` pages correctly. Two
judgement calls were good:

- `Anna Greynolds` cites `/staff/akrumpe` — slug and surname disagree, most
  likely a name change. Graded medium with the mismatch documented rather than
  asserted away.
- `Pip Kalungi` appears in the title as "Pip K"; the surname came from the
  slug. That is the template's combine-slug-and-title rule used correctly.

One record flagged for human review: **Anne Michal** (Texas A&M) — "Michal"
may be a middle name rather than a surname.

## Where the project stands

| org | held | last new/query | status |
|---|---|---|---|
| Ethnos360 | 534 | 2.7 | axes largely spent |
| RUF | 222 | 0.75 | **closed** |
| CCO | 119 | 0.53 | **closed** |
| CMML | 41 | 1.1 | search-capped (printed handbook) |
| Campus Outreach | 65 | 1.0 | weak |
| Avant | 12 | 0.67 | shallow |

Every worked domain is now at or below the retirement line. The next wave
should go to **untouched agencies via verify-then-dispatch** — the only method
that has opened a fresh 3–5/query seam (FMC 3.7, CCO 5.0 on first contact).
