# Wave w2026-09-10g — report

Five agents, 18 searches each (90), plus 6 orchestrator verification searches.
Four untouched agencies.

## Loaded

**174 people**, all Tier A. Coverage: 97 queries, 146 URLs.

| org | loaded | high | medium | new/query |
|---|---|---|---|---|
| Coalition for Christian Outreach | 90 | 90 | 0 | **5.0** |
| Reformed University Fellowship | 37 | 17 | 20 | 2.1 |
| Campus Outreach | 35 | 15 | 20 | 1.0 |
| Avant Ministries | 12 | 12 | 0 | 0.67 |

212 records emitted → 8 dropped → 204 loadable → 29 already held → **175 new**
(174 after one final dedup at insert). **1.9 new per query** overall.

## I was wrong about Campus Outreach

The brief called it "the strongest lead in the database" on the strength of
19 people held from cocolumbia.org against **one** spent query — 19 per query,
which I described as the best ratio in our coverage data.

That number was an artifact. Those 19 people came in incidentally from another
source; only one query had ever been *recorded* against the domain. Dividing
held-people by recorded-queries measures how badly coverage was recorded, not
how rich the seam is. Campus Outreach actually returned **1.0 new per query**,
the weakest of the four, and 29 of its 65 records were people we already held.

The lesson generalises: **people_held / queries_recorded is not a yield rate**
unless the coverage for that domain is known to be complete. Real yield is
new-people-per-query measured inside a wave. The domain-status view invites
the bad version of this calculation and should not be read as a forecast.

## CCO is the find

90 records, every one a distinct `ccojubilee.org/staff/<slug>` page with the
surname in the slug — no citation defects at all, the cleanest agent output of
any wave so far. 5.0 new/query, second only to Ethnos360's best.

CCO was the target I ranked *third* in the brief. The two I ranked first and
second (Campus Outreach, then RUF by population) came in at 1.0 and 2.1.

## RUF: the agent found a surface I missed

Verification concluded RUF had "directory indexes only" and I briefed the agent
to settle that question and stop early if the indexes did not name people.
Instead it confirmed ruf.org has no per-person pages, then **pivoted and found
`givetoruf.org/donate/<name>`** — RUF's separate giving platform, with real
per-person support pages. 37 people, 17 of them high confidence.

That is the brief working as intended: a target graded weak on the evidence
available, with an explicit instruction about what to do if the evidence
changed. Worth repeating for marginal targets rather than dropping them.

## Corrections applied at ingest

| count | correction |
|---|---|
| 7 | **CCO volunteers dropped.** An unpaid volunteer is not support-raised and is not a DonorSend prospect. My first count of these was 3 — I missed the ones whose role string carried a campus suffix. |
| 20 | RUF records citing a **campus code** (`givetoruf.org/donate/vandy`, `/bama`, `/ncsu`) regraded to `staff_directory`. These are per-ministry giving pages that name the campus minister, not pages about the person. The agent had already graded them `medium` and said why, which was right. |
| 19 | Campus Outreach records citing a **directory index** (`comemphis.org/staff`, `cosandiego.org/team`) regraded from `personal_page` to `staff_directory` / `medium`. |
| 9 | Campus Outreach records citing **first-name-only slugs** (`coatlanta.org/kyler`) downgraded to `medium` — a real personal page, but the URL does not carry the surname. |
| 1 | Dropped, no surname. |

## Surfaces confirmed for future waves

| org | pattern |
|---|---|
| CCO | `ccojubilee.org/staff/<initial+surname>` |
| RUF | `givetoruf.org/donate/<first.last>` — and `/donate/<campus-code>` for ministry pages |
| Campus Outreach | `co<city>.org` regional sites; `/give/<surname>` (Columbia), `/<first-name>` (Atlanta), `/<first-last>` (Central Florida) — the shape varies per region |
| Avant | `avantministries.org/missionary/<slug>` |

## What is worth another wave

- **CCO** — 90 found and the roster is larger; the campus-detail pages were
  barely touched.
- **RUF** — `givetoruf.org` was only reached in the last 8 searches. It has
  ~395 support-raised staff and we hold 37.
- **Campus Outreach** — only if approached region by region. Many city domains
  returned nothing (Philadelphia, Phoenix, Nashville, Milwaukee, New Orleans),
  so the region list itself needs establishing before mining.
- **Avant** — shallow, ~7 indexed profile pages. Not worth a second wave.
