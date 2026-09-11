# Wave w2026-09-10h — report

Four agents, 18 searches each (72). Continuation of CCO and RUF.

## Loaded

**113 people**, all Tier A. 123 emitted → 2 cross-agent dupes → 8 already held.

| org | loaded | high | medium | new/query |
|---|---|---|---|---|
| Reformed University Fellowship | 103 | 50 | 53 | **2.9** |
| Coalition for Christian Outreach | 10 | 8 | 2 | 0.28 |

**49 of the RUF records are interns** — a population that was at zero before
this wave. RUF now stands at 140 held, CCO at 100.

## RUF: the interns hypothesis was right

RUF reports 176 interns and we held none. Targeting them directly returned 55
records from 18 searches, and the campus-code sweep added 50 more from
campuses beyond the 19 already spent. 2.9 new/query on a domain we had already
worked once.

Because `givetoruf.org/donate/<first.last>` is a *guessable* URL shape, these
were checked for fabrication rather than trusted. The evidence says they are
real: the surnames are Cloutier, Concannon, Sesler, Tarter, Molicki, Sklena,
Phandara, Schaufelberger, Vanderworp, Leuenberger, Hoyme and Kreul — not what
invention produces, which is Smith and Johnson. Slug capitalisation is also
inconsistent across records (`Jackie.Lee`, `Caleb.sklena`, `Johnathan.Smith`),
a signature of URLs observed rather than constructed.

## CCO: the surname axis failed, and the measurement is clean

I designed a surname sweep on the reasoning that CCO slugs are
initial+surname, so a surname should be a searchable term — and that zero
J/N/Q/U/X/Y/Z surnames among 90 US staff looked like a sampling artifact,
since Johnson and Jones are top-25 US surnames.

The coverage settles it. **Eleven consecutive surname batches returned
`no_people`** — every J, N, U/V/Y/Z, D/L/O and common-surname batch. One batch
(Anderson/King/Wright/Baker) found anyone. Whatever the roster actually
contains, **a surname is not a working retrieval key against ccojubilee.org**,
and the missing-initials inference could not be tested this way.

Cost: 18 searches for 4 people, 0.22/query, the worst rate in this project.
That is a planning error, not an agent failure — I spent a full agent on an
untested technique.

CCO overall is now at 0.28 new/query across both its agents, against 5.0 in
w2026-09-10g. At ~100 held it is close to exhausted on the axes available.

## A brief-wording defect worth fixing

I listed the 90 held CCO surnames under "do not spend searches rediscovering
these". `cco-campuses` read that as a **person-level exclusion filter** and
withheld 14 people whose surname matched. I checked all 14 against the
database: 13 are genuinely the same people, and the fourteenth is Ryan
Ruffing, a CCO volunteer dropped at ingest last wave. So the outcome was
right — but only by luck. The rule as written would discard a genuinely
different person who happens to share a surname.

Future briefs should either list held FULL NAMES for this purpose, or state
explicitly that the list is a search-planning hint and never a filter.

The same agent also emitted 6 people already loaded in w2026-09-10g, so the
brief was simultaneously over- and under-applied.

## A geographic assumption of mine was wrong

I briefed CCO as a PA / Ohio / mid-Atlantic organisation. Its own
`campus-detail` enumeration shows it is **national**: College of Charleston,
Delaware, Fresno City College, Arcadia, UC Santa Cruz, Franklin & Marshall.
Those campuses went unsearched because my campus list pointed the agent at the
wrong region — a plausible reason CCO looks exhausted when it may not be.

## Grading corrections at ingest

| count | correction |
|---|---|
| 50 | `ruf-campuses` graded 42 of its 50 campus-code records `high`; the brief specified `medium`/`staff_directory` because the page belongs to the ministry, not the person. All 50 set to medium. |
| 4 | `ruf-interns` records citing campus codes rather than personal slugs, same regrade. |
| 8 | Already held (7 exact-name, plus Hannah Blankenship under a legacy `(Reformed University Fellowship (RUF))` suffix that exact matching missed). |

## Prose vs file

`ruf-interns` reported 56 records against 55 in its file. Fourth consecutive
wave with a prose/file mismatch despite the template rule.

## What is left

- **RUF** — still the best remaining target. 140 held against ~395; the
  intern axis produced 49 in one agent and is not exhausted, and campus codes
  beyond those now spent remain.
- **CCO** — only worth revisiting with the corrected national campus list
  (Charleston, Delaware, Fresno, Arcadia, UC Santa Cruz, Franklin & Marshall
  and whatever else `campus-detail` holds). The surname axis is dead.
