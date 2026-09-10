# Wave w2026-09-10e — report

Six agents, 18 searches each (108) plus 10 orchestrator verification searches.
First wave rendered from `prompts/enumeration.md` where the targets were chosen
against *corrected* coverage.

## Loaded

**234 people**, all distinct, all approved at ingest.

| org | loaded | high | medium | tier A |
|---|---|---|---|---|
| Ethnos360 | 63 | 63 | 0 | 58 |
| Family Missions Company | 59 | 59 | 0 | 59 |
| Macedonia World Baptist Missions | 40 | 40 | 0 | 40 |
| CMML | 37 | 0 | 37 | 37 |
| IBFI | 35 | 22 | 13 | 35 |

Agents emitted 270 records. 23 were dropped at ingest, 5 were the same person
twice, and 8 more turned out to be already held. Coverage: 118 queries, 150 URLs.

Org rollups after the wave: Ethnos360 345 held (333 Tier A), FMC 61, MWBM 43,
CMML 41, IBFI 38.

## What the corrected coverage changed

The 338-row query backfill for waves 09-10b/c/d landed before this wave was
planned. With it, WGM reads 100 queries for 125 people (1.3/query) and FMWM 27
for 38 (1.4) — both exhausted. Both looked cheap while their query coverage was
missing, and both would have been dispatched. That backfill paid for itself
immediately.

## Verification, again worth its cost

10 searches confirmed four patterns and killed four targets:

- **Frontiers USA** — everything routes to a pooled "Mission Fund"; no
  per-person pages, and Muslim-world workers are anonymized by design.
- **Eastern Mennonite Missions** — one directory page, no per-worker slug.
- **IMB / Alliance Missions / Christian Aid** — Cooperative Program, Great
  Commission Fund and indigenous-funded respectively. No support-raised staff.

All four are now in `hunt_negatives` as `no_individual_donors`. Ten searches
spent, roughly 54 avoided. Fourth wave running that verification has paid.

## New patterns confirmed

| org | pattern |
|---|---|
| CMML | `cmml.us/m/<id>`, giving at `cmml.us/donate/missionary/<id>`; IDs 42–1339 |
| MWBM | `mwbm.org/hp_wordpress/wp-content/uploads/YYYY/MM/Surname-Firstname-Month-Year.pdf` — **name in the filename** — plus per-missionary subdomains (`drcaudill.mwbm.org`) |
| IBFI | `ibfi.us/missionaries/missionaries-by-region/<region>/<slug>` and `ibfi.us/images/files/Missionary Prayer Letters/<Full Name>/` |
| FMC | `familymissionscompany.com/project/<slug>` |

MWBM and IBFI are the first two seams where the **filename or folder** carries
the name. That is a stronger citation than a directory listing and it survives
the site being unfetchable, since the URL alone proves the tie.

## Defects caught at ingest — 23 dropped

| count | defect | who |
|---|---|---|
| 12 | source_url was a **search-results URL** (`ethnos360.org/missionaries?query=Thailand`) — the agent's own query, not a page about the person | eth-deep |
| 5 | URL slug names a **different person** or withholds the surname (`kgoff` for "Kellie Herrera"; `kim-marie-krings` for "Kim Marie Capoun"; the Bennetts cited to the Yelles' page) | fmc, ibfi |
| 4 | **first name only** — a hard-rule violation that belongs in `needs_review` | fmc |
| 2 | story page, person not identified by the URL | eth-deep |

The search-results-URL failure is new and worth a template rule: an agent that
cannot find a person's page can produce a URL that *looks* like a citation
because the site echoes the query into the path. Twelve records, all high
confidence, all unusable.

## Confidence corrections

- **All 37 CMML records downgraded high → medium.** CMML keys pages by opaque
  numeric ID, and the template grades that `medium` even when the title names
  the person. Two agents graded 29 of them `high`.
- **12 IBFI records regraded** to `medium` / `staff_directory`: they cite the
  bare `ibfi.us/missionaries` index. That is a legitimate citation — a
  directory really does name them — but it is not a personal page.

An earlier draft of this report claimed CMML titles are always numeric. That is
wrong: some are (`Missionary #831`), some carry the name (`Missionary #227 -
Pierce, Floyd & Helen`). The downgrade stands regardless, because it turns on
the URL, not the title.

## Open items

- The **Cacho-Hansens are cited to two different IDs** (m/282 by cmml-low,
  m/840 by cmml-high). One is wrong and neither URL carries a name. One record
  pair was kept at medium; a reviewer should resolve the ID.
- **cmml-low went out of slice**, returning m/732 and m/866 from cmml-high's
  range, and returned only 13 people for 18 searches. Slice discipline held
  everywhere else.
- Two Ethnos360 couples sit on `homes.ethnos360.org` (a retirement-homes site)
  and are graded Tier A. They may be retired rather than actively supported.

## Yield

CMML remains the deepest unmined seam we have found since Ethnos360 — the
prayer handbook lists 750+ commended workers and we hold 41. MWBM, IBFI and FMC
all look close to exhausted at this depth; each agent reported repeats in its
last three searches.
