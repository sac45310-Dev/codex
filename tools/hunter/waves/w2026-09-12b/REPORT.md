# Wave w2026-09-12b — International Students, Inc.

**147 people loaded. 96 searches. 1.53 net-new per query after cross-agent dedupe.**
Retirement line is 1.3–1.4. `roster_status` set to **partial**, not exhausted.

| agent | slice | searches | emitted | reported /q |
|---|---|---|---|---|
| isi-a | Northeast and Mid-Atlantic | 24 | 61 | 2.5 |
| isi-b | South and Southeast | 24 | 61 | 2.5 |
| isi-c | Midwest and Mountain | 24 | 78 | 3.25 |
| isi-d | West Coast, roles, couple-slug probe | 24 | 84 | 3.5 |

**284 raw records → 153 distinct names → 147 loaded.** All `high` confidence,
`fit_score` 9, Tier A, `personal_page`. Every slug found carried the surname, so
rule 3's `medium` branch never fired once — the first wave in the session where
the confidence ceiling was not capped by opaque IDs. 97 distinct `/team/` pages
behind 147 people: roughly a third are couple pages yielding two records each.

## Read the yield honestly

Each agent reported 2.5–3.5 new-per-query against *its own* running set. The
number that matters is against the CRM after merging all four, and that is
**1.53**. The agents overlapped heavily — 79 of 153 names were found by two or
more of them — because role queries cut across geography and pulled the same
people into four different slices. The wave clears the retirement line, but by
less than any single agent's self-report suggests. This is the same
denominator error wave w2026-09-12a hit in the opposite direction, and it is
worth building into the template: **per-agent yield is not wave yield.**

## I got the axis wrong, and all four agents corrected it

The brief led with geography because ISI puts city and state in the indexed
snippet. It does. But **the tokens being present and the tokens being rankable
are different things** — the same distinction wave u ran into between "the
roster is deep" and "search can see the roster".

Bare state names collide with college-sports pages and return ISI's own state
landing pages (`/ohio-2/`, `/michigan/`, `/nevada/`), which outrank and crowd
out the person pages. What the index ranks on is the **role phrase**:

| query | new people |
|---|---|
| `"Area Director" Northeast` | **17** |
| `"City Director" Philadelphia Baltimore Boston` | **15** |
| `Campus Director Southeast Region` | **13** |
| `Campus Staff Arizona Tempe Tucson` | 13 |
| any bare state name | 0–2 |

Three of the four agents hit the three-consecutive-empty stop rule and all
three correctly declined to stop, because in each case the dry spell was one
query shape failing rather than the surface exhausting. Agent A sat through
**six** consecutive empties before switching shape, then produced the four
largest yields of its run. **The stop rule as written measures the query shape,
not the surface.** It needs to be scoped: three consecutive empties *on
different query shapes*.

## The couple-slug shape is the high-yield structure

Agent D was assigned to probe it and found **83% of its yield lived there** — 35
of its 49 distinct pages were couples. The shape is also more varied than the
brief claimed. Alongside plain plurals (`/team/carrolls/`, `/team/smuckers/`)
ISI uses **bare singular surnames for couples** (`/team/meyer/`, `/team/innis/`,
`/team/downs/`) and occasional full two-name slugs
(`/team/nick-and-nicole-miller/`). An agent reading the slug rather than the
title would silently lose the second person on every one of those.

## Protections: 10 people held back, and 6 of them were a cross-agent conflict

The volunteer trap the brief warned about was real, and it exposed something
about multi-agent waves I had not seen before: **the same person can be emitted
by one agent and held back by another.** Six were.

| person | rule | emitted by | held by |
|---|---|---|---|
| Simon & Becky Zeigler | 9 — "served with ISI 1998–2011", no current role | A, C, D | B |
| Ron & Beth Mills | 9 — "served international students for 23 years", no current role | D | C |
| Samuel & Joanne Carroll | 6 — "began volunteering with ISI", no staff role stated | A, B, D | C |

**The protection wins, always.** All six are loaded as `skipped` with the
reason on the record rather than dropped, so a human can check the live page
and promote them. Four more were held for the same class of reason: Jill
Mitchell (page names her an ISI **Ministry Rep**, a separate track from
support-raised staff), and Hal Schaeffer, Yoriko Livingston and Jordan Lassiter
(named in page text but not in the page title, so not confirmed as staff).

Two were **not** written to the database at all, correctly: "Emily" on
`/team/josh-tidd/` and "Kent" on `/team/anne-adrian/` are first names with no
surname in the title. Rule 8 says never emit and never resolve from another
source, and that includes not creating a row. Two more had no citable page at
all — See Seng Tan (ISI President, named only on directories) and Rebekah
Miller (an author byline on the archive index).

Mark Zeigler (`/team/mark-zeigler/`, Dallas) is a **different person** from the
Zeiglers held back, and was loaded.

## `/team/` is necessary but not sufficient

Agent C found `/team/denver_auraria/` (a location page) and
`/team/isi-memorial-gift/` (a fund) sitting in the person namespace. Rule 1 as
written — "emit only pages under `/team/`" — would have passed both. The agents
caught them by reading the title; the rule should say so.

## Not exhausted

Agent D found new people on its last budgeted query, and agent B's final query
returned three. LA, MS, AR, AL, SC, NV, AK, HI, UT, MT, WY and the Dakotas
returned nothing under any shape — either genuinely unstaffed or not surfacing
those tokens. A second pass driven purely by role phrases and couple-slug
shapes, with geography dropped entirely, is the obvious continuation and would
satisfy the refined rule from wave x: budget-limited, with a credible roster
estimate (**677 campuses**) far larger than `headcount_found` (147).
