# Wave w2026-09-11o — Cadence International, straight enumeration

Five agents, 90 searches, **62 net new people — 0.69 per query. Below the
1.3–1.4 retirement line. Cadence is retired at 204.**

Database total 4,471.

## Result

| agent | searches | raw | rate (raw) |
|---|---:|---:|---:|
| cad-us-east | 18 | 118 | 6.6 |
| cad-role | 18 | 107 | 5.9 |
| cad-europe | 18 | 85 | 4.7 |
| cad-us-west | 18 | 68 | 3.8 |
| cad-pacific | 18 | 57 | 3.2 |
| **total** | **90** | **435 raw → 193 unique → 62 net** | **0.69** |

All five files zero-defect: no search-results URLs, no malformed names, no
in-file duplicates, every record `personal_page` / `high` / Tier A.

## I was wrong to expect another 8.0

Wave n took 144 people from 13 searches and reported that exclusion sweeps
"were still returning new slugs" when its budget ran out. I read that as an
unexhausted seam and recommended a full re-dispatch. **The signal was
real but meant something narrower than I took it to mean.**

The gap between 435 raw and 193 unique is the tell: the five agents were
overwhelmingly finding *each other's* people. The `cad-role` agent
diagnosed it precisely — the engine cycles between two fixed ~10-result
clusters for `site:cadence.org/missionary`, and past saturation more
exclusion terms stop re-ranking anything. Wave n's sweeps were productive
because the pool was still fresh, not because the roster was deep.

204 people is probably close to Cadence's full search-visible roster.

## Exclusion sweeps: a measured limit

Three agents independently characterised the same failure, which makes it
trustworthy:

- **They degrade rather than fail.** Past roughly a dozen negative terms
  the engine silently drops the operators and re-serves excluded surnames.
  `cad-pacific` saw 3 of 11 negatives ignored; `cad-role` saw Amor,
  Argueta, Bloker and Auldridge returned inside queries excluding them.
- **`cad-us-west` saw byte-identical result sets** on sweeps 3 and 4
  versus sweep 1.
- **The practical cap is about ten terms**, and an identical result set is
  the stop signal — not a reason to buy more.

The useful refinement, from `cad-role`: pair exclusions with one narrow
qualifier so the engine has to re-rank, rather than buying bare sweeps.

## Two axes that beat base names

Both worth carrying to any future military-ministry target:

- **Ministry house names beat installation names.** "Soldiers Hospitality
  House", "STRIDE House", "47 North", "The Dwelling Place", "The Harbor",
  "Wired Bean", "Home Port" all pulled named directors where the base name
  returned nothing. `cad-us-west` called it the single best query of its
  run; `cad-pacific` said the house axis "beat the base-name axis
  decisively".
- **Role and leadership terms reach people geography cannot.** "Director
  of" / "Vice President" surfaced five headquarters staff no geographic
  query would touch, and "Partnership Development" is the handle for
  pre-field staff.

## The memorial rule earned its place five more times

Five two-name slugs carry one-name titles: `/dick-and-margaret-patty/` →
"Margaret Patty", `/ben-and-doris-hyde/` → "Doris Hyde", `/john-and-joan-
hobson/` → "Joan Hobson", `/ben-and-connie-cady/` → "Connie Cady",
`/ken-and-julie-converse/` → "Julie Converse", `/jay-and-jerri-kayll/` →
"Jerri Kayll". Three separate agents caught these independently and
emitted only the titled spouse.

**A sixth case needed an orchestrator call.** A legacy URL shape exists on
this domain — `cadence.org/missionaryPage/camp` — titled "Ralph & Betty
Camp", while the current `/missionary/ralph-camp/` names only Ralph. One
agent emitted both from the legacy page. I withheld Betty: when an old URL
names two people and the current page names one, the current page is the
authority, and the disagreement is itself the memorial signal.

Without the split-on-title rule added in wave n, this wave would have put
at least six probably-deceased people into a sales queue.

## Other judgement calls

- `/missionary/tim-and-rebecca-hawkins` returned titled "Redirection" —
  slug names two, title names none. Both withheld.
- `larry-and-bb-blakely`: "BB" is a published given name with a full
  surname at a US base, not sensitive-region anonymization. Larry emitted;
  BB held, because a two-letter given name is indistinguishable from an
  initial without the page.
- Two Sprague households and two Lambert households exist on this domain.
  Both pairs are recorded with a do-not-dedupe-on-surname note carried in
  `fit_reason` so it survives into the CRM.

## What is left, and it is not searchable

Named ministry houses whose current directors appear nowhere in the search
index: The Haven (North Pole AK), The Homestead (Eagle River AK), Travis
Hospitality House, GK-Brunssum (Netherlands), North Colorado Springs, and
the post-Bloker directors at Soldiers Hospitality House. Plus
`cadence.org/missionary-directory/`, which surfaced in three separate
searches and would settle the whole roster in one fetch.

Roughly thirty named installations returned no Cadence presence at all —
Guam, Quantico, Fort Belvoir, Fort Drum, West Point, Aberdeen, Dover,
Parris Island, Fort Campbell, Fort Knox, Eglin, Mayport, Stuttgart,
Ansbach, Mildenhall, Alconbury, Sigonella, Belgium, Turkey, Greece among
them. Grafenwoehr's own page says it is currently unstaffed. Read those as
genuinely unstaffed rather than unmined; the installation directory would
confirm it far more cheaply than more search budget.

## Next

Cadence is retired. Wave p goes to Ratio Christi — found on the last
search of wave n, essentially unmined at 2 people, and needing per-person
screening because it runs volunteer tent-maker chapter directors alongside
supported missionaries.
