# Wave w2026-09-10n — untouched agencies, surface-discovery shape

**Dispatched** 2026-09-10, ingested 2026-09-11. Four agents, 72 searches,
**209 net new people — 2.9 per query.** Well above the 1.3–1.4 retirement
line, and the answer to the question the last two waves raised.

Database total **4,409**.

## Result

| agent | agency found | searches | raw | net | rate (net) |
|---|---|---:|---:|---:|---:|
| n-youth | **Cadence International** | 18 | 144 | 142 | **7.9** |
| n-baptist | World Wide New Testament Baptist Missions | 18 | 78 | 27 | 1.5 |
| n-intl | **Encompass World Partners** | 18 | 42 | 32 | 1.8 |
| n-catholic | **Youth Apostles** | 18 | 8 | 8 | 0.44 |
| **total** | | **72** | **272** | **209** | **2.9** |

Zero search-results URLs, zero malformed names, zero cross-file duplicates
across all four files.

## The wave was reshaped before dispatch, and that was the right call

Ten pre-dispatch probes on the obvious untouched agencies — Mission to the
World, Wycliffe, TEAM, Pioneers, Serge, Baptist World Mission, Gospel
Fellowship, Crossworld, Christar, Damascus — found **no readable per-person
page anywhere**. Rather than send four agents to enumerate agencies whose
surface I had not confirmed, the wave was re-pointed at *finding* agencies
that still have one.

That produced four live agencies in 72 searches, three of them new to the
database. Guessing agency names had a 0-for-10 hit rate; surveying URL
shapes had 4-for-4.

## Cadence International is the find

**144 people from 13 mining searches — 8.0 per query, the best rate this
project has recorded.** Clean archetype: `cadence.org/missionary/
<first>-and-<first>-<last>/`, titles reliably carrying the couple names, so
the couple-split rule applied across nearly the whole roster.

Military-community ministry — hospitality houses on and near bases in
Germany, Japan, Okinawa, Korea, Italy, Spain, England, Alaska and across
the US. Cadence's own giving copy says missionaries raise ministry
expenses, benefits **and monthly salary**, which is why headquarters and
mobilization staff with a `/missionary/` page are Tier A alongside field
staff.

**It is not exhausted.** Exclusion sweeps were still returning new slugs
when the budget ran out. This deserves a straight enumerate-one-agency
re-dispatch, and it is the highest-confidence work available right now.

## The other three

**Encompass World Partners** — the Charis Fellowship / Grace Brethren
agency, untouched precisely because the name does not read as a missions
agency. It inverts the usual slug/title relationship: most slugs are first
names only (`/person/steveandceleste`, `/person/junko`) with the surname
living in the page title, so those grade `medium`; a newer minority carry
the surname and grade `high`. Judge per record, like Converge.

**Youth Apostles** — a structural lesson more than a haul. Per-person pages
sit at the **site root** as flat concatenated slugs (`/tylerfabian`), not
under a `/missionaries/` prefix. That gives the search engine no path to
enumerate, so every `site:` query returns the same handful of pages mixed
with blog content. Eight people, and the roster is not exhausted — one
fetch of `/missionaries` would close it.

**Ratio Christi** — found on the literal last search of the budget and
essentially unmined: two people. `give.ratiochristi.org/missionary/
<first>-<last>` plus a chapter index. Deserves its own agent, **with
screening** — Ratio Christi runs volunteer tent-maker chapter directors
alongside supported ones, and a volunteer is not an ICP fit.

## My error: WWNTBM was not untouched

The baptist agent's hit, World Wide New Testament Baptist Missions, **had
already been mined in wave w2026-09-10a** — 60 records, plus 11 from
earlier scraping. My brief's "already worked" list was written from memory
and omitted it, so an agent spent most of a wave slot rediscovering known
ground.

The dedup guard contained the damage: 51 of 78 were already held, 27 were
genuinely new, and the agent did add real value by finding that the seam
is still producing. But the fix is procedural and obvious — **the
already-worked list in a brief must be generated from the database, not
from recall.** Had I run one query before writing the brief, that slice
would have gone to five untested agencies instead.

## The memorial trap — promoted to the template

Two WWNTBM pages pair two first names in the slug but have been quietly
rewritten after a death: `/elwood-and-doris-hurst/` is titled "Elwood
Hurst" (Doris died 2024) and `/norman-and-joy-johnston/` is titled "Joy
Johnston" (Norman died 2018). The agent emitted only the living spouse
from each and flagged both.

A naive splitter on this URL pattern would have emitted deceased people as
sales prospects. That is the worst error this pipeline can make, and the
slug alone walks you straight into it. The rule is now in
`prompts/enumeration.md`: **split couples on the TITLE, never the slug.**

## Seventeen agencies mapped and closed

The misses are half this wave's value and are all in `hunt_negatives` with
the actual surface recorded. Highlights worth remembering:

- **Christ in the City** has exactly the right URL shape but publishes
  first-name-plus-initial **deliberately** — young adults doing street
  ministry with people experiencing homelessness. Recorded as unrecoverable
  by design, not as a gap to reattack. The anonymization should be
  respected.
- **Catholic Christian Outreach (Canada)**, `cco.ca`, is the closest
  near-hit after Youth Apostles: explicit personal support-raising, a
  regional roster, nothing indexed below `/our-missionaries/`. Flagged
  loudly because it is **not** the already-worked Coalition for Christian
  Outreach — same initials, different organisation.
- **Totus Tuus** is not one agency at all: a diocesan summer program run
  separately by each diocese with seasonal diocese-paid teachers. No
  national roster, no support-raising.
- **Miles Christi** is a religious order under vows, not support-raised
  staff — a poor archetype fit regardless of surface.
- **Student Mobilization** is login-gated nationally, but campus
  subdomains (`tcu.stumo.org/staff.html`) carry flat rosters a
  fetch-enabled wave could harvest.

## Unprobed, not negative

The brief's stop-and-mine rule fired early for three of four agents, so
these were never reached and must not be treated as dead: Evangelical
Baptist Missions, BBFI, Independent Faith Mission, Bible Baptist Missions,
Baptist Church Planters (`bcpusa.org`); Young Life, Youth for Christ,
Search Ministries, OCF, Christian Union, Greek InterVarsity; Reach Beyond,
e3 Partners, Global Frontier Missions, InterAct, JAARS, MAF, Pioneer Bible
Translators, Resonate; and Women Youth Apostles. Continental Baptist
Missions was probed on the **wrong domain** (`cbmin.org` is Canadian
Baptist Ministries) and remains open.

## Coverage recorded

69 query rows under `w2026-09-10n`, plus 17 agency verdicts written to
`hunt_negatives` rather than coverage, because `hunt_coverage.kind` allows
only `url` and `query` and an agency verdict is neither.

## Next

**Cadence International, straight enumeration.** 8.0 per query, confirmed
slug shape, confirmed not exhausted. Then Ratio Christi with volunteer
screening, then the unprobed list above — and generate the already-worked
list from the database this time.
