# Wave w2026-09-12d — ISI university axis, re-run with `blocked_domains`

**16 net-new from 24 searches — 0.67 per query.** Under the 1.3–1.4 retirement
line. **ISI stays `exhausted`, now at 186 held** — the same verdict as wave c,
but reached on a working measurement instead of a broken one.

One agent, 24 queries, every one carrying `blocked_domains: ["en.wikipedia.org"]`.

## Question 1 — did `blocked_domains` fix the axis? Completely.

| | wave c (no `blocked_domains`) | wave d (with it) |
|---|---|---|
| queries returning person pages | 9 of 24 | **24 of 24** |
| Wikipedia URLs in result lists | swamped 15 queries | **0** |
| off-domain URLs of any kind | many | **0** |
| person pages per productive query | variable | 7–10, every query |

Every query wave c logged as `offtopic` (Vanderbilt, Rutgers, Syracuse,
Buffalo) or `no_people` (Ohio State, Michigan State, Penn State, Texas A&M,
Georgia Tech, Emory, UMass) returned a full page of people here. No other
hosts needed blocking — Wikipedia was the whole problem.

The brief predicted that state-containing names (`Georgia Tech`, `Ohio State`)
would still degrade to ISI's own state landing pages, since those are
on-domain and `blocked_domains` cannot touch them. **That did not happen** —
all ten returned person pages only. The landing-page collision wave c reported
may itself have been a downstream effect of the Wikipedia flood displacing
better-ranked on-domain results. Worth knowing, not proven.

## Question 2 — did the collision hide people? Yes, modestly.

105 records, 73 distinct pages. Deduped against the CRM: **16 people on 11
pages that no wave had ever found** — Doug Sawyer, Sundeep Malickal, James &
Paige Frailey, Sarah Halferty, Paul & Katie Sultan, Amarildo & Laura Moreira,
Perla Macias, Ron & Betsy Manila, Scott Hawkins, Scott & Kathy Matheny, Calen
Thomas.

**Eight of those eleven pages came from the five queries wave c lost to the
collision** (Michigan State, Penn State, Texas A&M, Georgia Tech, Vanderbilt).
The tooling error had a real cost: about 9% of the roster.

But 0.67 per query is still under the line. Wave c's *verdict* was right; its
*reasoning* was wrong. Those are different failures and this wave separates them.

## A correction to my own brief

I wrote *"the same university list wave c used, so the comparison is clean."*
It was not the same list. Wave c's agent substituted names as it went — it
never ran Virginia Tech, NC State, Iowa State, Kansas State, Arizona State or
Oregon State, and did run Illinois, Washington, Stanford and Harvard/MIT
instead. The agent caught this and reported it; I had assumed the brief's list
was the list actually run. **A brief that claims to replicate a prior wave
must be built from that wave's `coverage` array, not from its brief.** Three of
the eleven new pages came from names wave c never ran, so the "hidden by the
collision" count is 8 pages, not 11.

## The university token is a sampler, not a filter

This survives from wave c and `blocked_domains` does not change it. Only about
a third of queries were on-target (Purdue → Flamminis/Wilsons; Texas A&M →
Shirk; NC State/Duke → Kronstads, Hawkins, Manilas; Oregon State → Smuckers;
UConn → Alumbaughs; Buffalo → Kuechle). The rest returned a rotating fallback
set — the Pierces, Strouds, Caspers, De Paduas, Skinners and Claassens each
appeared in ten or more result lists. The axis works, but it cannot be walked
like a directory; it samples the namespace with a mild bias toward the named
campus.

## Rules held

- **0 hold violations** across 105 records. All seven bound holds that
  surfaced were routed to `needs_review` and not emitted.
- **Role inheritance did not recur.** `role` is set on 4 of 105 records — only
  where the indexed text named a title for that specific person — and null
  everywhere else. Steve Dunne and Patrick Flynn, whose spouses were held back
  as Ministry Representatives in wave c, are emitted with no role rather than
  a copied one.
- `city`/`state` never set; the agent declined to infer them from the
  university's location, as instructed.
- Two `needs_review` entries for plural-slug/single-name pages (`/claassens/`,
  `/shirks/`) where a second person may exist but is not in the title.
- All 105 `high` / 9 / Tier A / `personal_page`; every slug carried the surname.

## What this closes

ISI is done, on evidence that now holds up: three waves, 185 searches, four
axes, 186 people, and the last axis re-tested after the tooling defect that
distorted it was found and fixed. The template's `blocked_domains` guidance is
no longer a lab result — it has been used in a live wave and did exactly what
the tests said it would.
