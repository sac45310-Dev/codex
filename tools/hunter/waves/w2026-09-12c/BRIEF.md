# Wave w2026-09-12c — International Students, Inc., second pass

## Why a second pass

Wave w2026-09-12b loaded 147 at 1.53 net/query after dedupe, and **agent D was
still finding new people on its last budgeted query**. That is the
budget-limited signature wave x's rule asks for.

**Be honest about the other half of that rule.** Wave x says continue only when
budget-limited *and* a credible roster estimate is far larger than
`headcount_found`. The number I have is "677 campuses", which is campuses, not
staff. It is not a roster estimate and I should not dress it up as one. The
honest position is that the roster size is **unknown** and this pass is what
establishes it. If yield lands at or under 1.3–1.4, ISI is done.

## What wave b established — do not re-derive it

| finding | consequence for this brief |
|---|---|
| Bare state names collide with college-sports pages and return ISI's own state landing pages | **Geography is dropped entirely from this wave** |
| Role phrases are what the index ranks on — `"Area Director" Northeast` returned 17 in one query | Role phrases are axis A |
| 83% of agent D's yield was couple pages | Couple slugs are axis B |
| Couple slugs vary: plural (`/carrolls/`), **bare singular surname** (`/meyer/`, `/innis/`, `/downs/`), and full two-name (`/nick-and-nicole-miller/`) | Read the **title**, never the slug, to get both names |
| `/team/` contains non-people — `/team/denver_auraria/` (a location), `/team/isi-memorial-gift/` (a fund) | Path is necessary, never sufficient |

Already spent and recorded in `hunt_coverage`: the role-phrase axis at breadth,
the bare-state axis (dead), and one couple-slug probe. **147 people are already
held.** Do not use an exclusion list — the operator ceiling is ~10–12 terms and
exclusion lists have hidden real people before. Emit everything that qualifies;
the orchestrator dedupes at ingest against 6,851 person records.

## Rules — all unconditional

1. **Emit only `internationalstudents.org/team/<slug>` pages, and only when the
   page title is a person's name.** `/team/denver_auraria/` and
   `/team/isi-memorial-gift/` are under the path and are not people. No exceptions.
2. **A record is `high` confidence.** No exceptions.
3. **A slug that does not contain the surname makes that record `medium`.** Say
   why in `fit_reason`. No exceptions.
4. **`evidence_basis` is `personal_page`.** No exceptions.
5. **`fit_score` is 9 for `high`, 7 for `medium`. Tier A throughout.** No exceptions.
6. **A page identifying the person as a volunteer or a ministry Rep goes to
   `needs_review` and is not emitted.** ISI runs a separate Ministry
   Representative track. Emit staff, campus staff, campus directors, area
   directors, city directors, team leaders. No exceptions.
7. **A couple page yields two records, one per named person, both citing the
   same URL — and the names come from the page title, not the slug.** No exceptions.
8. **Emit a second person only when the page title names them.** If the title
   names one person and the body names a spouse, the spouse goes to
   `needs_review`. No exceptions.
9. A title giving initials only, a first name only, or a codename goes to
   `needs_review`, is never emitted, and is never resolved from another source.
   No exceptions.
10. A closed date range with no current role stated goes to `needs_review` as a
    suspected retiree. A closed range *with* a current role is fine. No exceptions.
11. **Never record or infer any individual's demographic or identity
    attributes.** No exceptions.

## Stop rule, corrected

Wave b's three agents all hit three consecutive empty searches and all three
were right to keep going, because the dry spell was one query shape failing.
**Stop after three consecutive empty searches on three *different* query
shapes.** Three empties on the same shape means change the shape.

## Axes — 24 queries each, 72 total

- **agent A — role phrases, exhaustively.** Campus Staff, Campus Director, Area
  Director, City Director, Regional Director, Team Leader, Campus Coordinator,
  Ministry Leader, Director of Training, Field Director, International Student
  Ministry, plus support-raising language ("ministry partners", "raising
  support", "partner with us"). Rotate each against nothing else, then against
  a single broad qualifier.
- **agent B — surname and couple-slug enumeration.** Probe the three couple slug
  shapes directly with common American surnames, and probe alphabetically.
  Report which of the three shapes yields most.
- **agent C — campus and university names, not states.** Wave b found quoted
  metro cities worked where bare states did not; **university names are the
  untested variant and ISI is a campus ministry.** Purdue, Ohio State, Michigan
  State, Penn State, Texas A&M, Georgia Tech, Virginia Tech, NC State, Iowa
  State, Kansas State, Arizona State, Oregon State, UCLA, Berkeley, Duke, Emory,
  Vanderbilt, Rice, Cornell, Rutgers, UMass, UConn, Syracuse, Buffalo.

Report `new_people_found / queries_run`. Search titles, URLs and snippets only —
WebFetch is EGRESS_BLOCKED.
