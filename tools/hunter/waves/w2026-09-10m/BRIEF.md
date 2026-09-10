# Wave w2026-09-10m — FOCUS via third-party campus rosters

**Target:** FOCUS (Fellowship of Catholic University Students)
**Agents:** 4 · **Budget:** 18 searches each

## Read this first: focus.org itself is search-capped

I planned this wave as "more campuses on focus.org" and **the probes killed
that plan.** Four pre-dispatch searches:

| probe | focus.org person pages | new to us |
|---|---:|---:|
| Saint Louis U / UT Dallas / Houston / Sacramento State | 2 | **0** |
| Akron / Youngstown / John Carroll / Cleveland State / Case Western | 0 | **0** |
| surnames: Nguyen / Kowalski / Hoffman / Sullivan / Fitzgerald | 3 | **1** |
| "first year missionary 2026" | 0 | **0** |

For comparison, every wave-l probe returned **ten new out of ten**. We hold
451 of ~981 FOCUS missionaries, so they exist — but the search index will not
hand over many more from `focus.org/missionaries` directly. Do not spend this
wave there.

## The live seam: the campuses publish the teams

FOCUS serves 200+ campuses through Newman Centers, Catholic student centers
and diocesan campus ministries, and **those sites publish their FOCUS team
rosters** — `bulldogcatholic.org/missionaries/2025-2026-missionaries`,
`huskercatholic.com/meet-the-missionaries`, `uwnewman.org/focus-at-uw`,
`iowacatholic.org/focus-missionaries`, `bisoncatholic.org/focus`,
`calnewman.org/students/focus`, `uonewman.org`, `newmanec.com`,
`saintbenedictinstitute.org`, plus diocesan news ("FOCUS Missionaries arrive
at SDSM&T — Diocese of Rapid City"). None of this has ever been searched.

This also reaches the Northeast, which wave l proved is unreachable through
`focus.org` campus-name search. If those people are findable at all, they are
findable here.

## Work in two stages

1. **Harvest** a roster page: find the campus ministry site, read the team
   names off the title and snippet.
2. **Confirm** by batching those names back at focus.org in ONE query —
   `site:focus.org/missionaries "Katie Pattee" OR "Nicholas Fornarotto" OR ...`
   Do not spend one search per person.

Grade on what you end up with:

| what you have | evidence_basis | confidence |
|---|---|---|
| stage 2 found their `focus.org/missionaries/<slug>` page | `personal_page` | `high` |
| only the roster page names them, full first **and** last name | `staff_directory` | `medium` |
| roster gives a first name only | **do not emit** |

Everything is still **Tier A** — FOCUS states all missionaries raise 100% of
their own support, so `staff_directory` here means "we have a weaker citation",
not "a weaker prospect". `source_url` is whichever page you actually cite.

## The trap on this axis: first-name-only rosters

Many of these pages list teams as *"Colton, Bella, Veronica, Teddy, Katie and
Jack"* — that is a real snippet from the probe. **First names alone are not a
record.** They collide directly with the standing no-first-name-plus-initial
rule. If a roster gives only first names, cite nothing, log the page in
`coverage[]` as `no_people`, and move on. Do not pair a loose first name with
a surname from somewhere else — that is invention.

Watch for two more: some pages list **student leaders and chaplains alongside
FOCUS missionaries** (a priest or a "student president" is not a FOCUS
missionary), and some rosters are **stale**, naming a team from 2019. Prefer
pages that state a current year, and say in `fit_reason` which year the roster
claims.

## Slices — stay inside yours

### `focus-newman-mw` → `newman-mw.json`
Midwest and Plains Newman Centers / Catholic student centers: North & South
Dakota, Nebraska, Kansas, Missouri, Iowa, Minnesota, Wisconsin, Michigan,
Illinois, Indiana, Ohio. Known live: bulldogcatholic.org (NDSU),
huskercatholic.com (Nebraska), bisoncatholic.org (Fargo), iowacatholic.org,
uwnewman.org, CoMo Newman (Missouri), Diocese of Rapid City.

### `focus-newman-south` → `newman-south.json`
South and Southeast: Texas, Oklahoma, Arkansas, Louisiana, Mississippi,
Alabama, Georgia, Florida, Tennessee, Kentucky, the Carolinas, Virginia.
Diocesan campus-ministry pages are strong in this region.

### `focus-newman-east` → `newman-east.json`
Northeast and Mid-Atlantic: New England, New York, New Jersey, Pennsylvania,
Maryland, DC, Delaware. **This is the highest-value slice** — wave l showed
these campuses are invisible from focus.org, so third-party rosters may be the
only route to them. Newman Centers, Catholic Campus Ministry pages, and
diocesan sites for Boston, Providence, Hartford, Albany, Buffalo, Rochester,
Scranton, Harrisburg, Philadelphia, Baltimore, Arlington, Wilmington.

### `focus-newman-west` → `newman-west.json`
West, Southwest, Mountain, Pacific: Colorado, Utah, Montana, Idaho, Wyoming,
Arizona, New Mexico, Nevada, California, Oregon, Washington. Known live:
calnewman.org (Berkeley), uonewman.org (Oregon). Also take the **international
campuses** here, and retry Austria in **German** — Universität Graz, Wien,
St. Pölten, Hochschulgemeinde, Katholische Hochschulgemeinde — which wave l
identified as the likely reason Austria came back empty in English.

## Do not re-buy these — established dead ends

- **Negative `-surname` exclusions do not work on this domain.** Two searches
  in wave l returned result sets identical to their unexcluded counterparts.
- focus.org campus-name search for the Northeast, and for Georgia, UCF, USF,
  UNC, NC State, Nebraska outside Lincoln, TCU, Cal Poly, Nevada-Reno,
  New Mexico State, Akron/Youngstown/John Carroll/Cleveland State/Case Western,
  Saint Louis University, UT Dallas, Houston, Sacramento State.
- Digital Outreach never names its team in a snippet.
- Irish, Polish and African given names on focus.org: empty.
- The four probe queries at the top of this brief. They are spent.

## Everything else

Follow `tools/hunter/prompts/enumeration.md` exactly, including the couple
rules (a roster may name a married pair — that is two records), the
**children are not missionaries** rule, sensitive/anonymized workers to
`needs_review`, never record or infer demographic or identity attributes,
log queries that found nothing in `coverage[]`, and **do not state a count in
your closing message.**

We hold 451 FOCUS people. The orchestrator dedupes — **the held set is a
planning hint, NEVER A FILTER.** If you find a person, emit them.
