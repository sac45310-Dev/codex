# Wave w2026-09-11o — Cadence International, straight enumeration

**Target:** Cadence International, `cadence.org`
**Pattern (confirmed, do not re-derive):**
`cadence.org/missionary/<first>-and-<first>-<last>/`
with a single-name variant for unmarried staff (`/missionary/beth-mabry/`),
an occasional no-"and" form (`/missionary/john-marcie-good/`), and rare
surname-only (`/missionary/sprague/`).
**Agents:** 5 · **Budget:** 18 searches each

Cadence is military-community ministry: hospitality houses on and near
bases in Germany, Japan, Okinawa, Korea, Italy, Spain, England, Alaska and
across the United States.

## Tier

**Every record is Tier A.** Cadence's own giving copy says missionaries
raise ministry expenses, benefits **and monthly salary**. That covers
headquarters, mobilization and Student Ministry staff as well as field
staff — if a person has a `/missionary/` page, they are Tier A. Role is not
a tier signal.

## Why we are back

Wave n found this seam on a discovery agent's first survey search and mined
it with only 13 searches, returning **144 people — 8.0 per query, the best
rate this project has recorded.** Both exclusion sweeps were still
returning new slugs when the budget ran out. We hold 142. The roster is
demonstrably not exhausted.

## What worked, and what to do differently

Wave n's productive axes were **geography** and **role/status**, and
critically **`-surname` exclusion sweeps kept producing on this domain** —
unusual, and the opposite of FOCUS, where exclusions were inert. Use them.

Five directory index URLs were logged for a fetch-enabled pass; fetching is
still blocked, so work from search.

## Slices

### `cad-europe` → `europe.json`
Germany (Kaiserslautern, Vilseck, Wiesbaden, Spangdahlem, Baumholder,
Landscheid, Ramstein, Grafenwoehr, Ansbach, Stuttgart), Italy (Vicenza,
Aviano, Naples, Sigonella), Spain (Rota), England (RAF Lakenheath,
Mildenhall, Alconbury), Belgium, Netherlands, Turkey, Greece.

### `cad-pacific` → `pacific.json`
Japan (Yokosuka, Yokota, Misawa, Iwakuni, Sasebo, Atsugi, Zama), Okinawa
(Kadena, Hansen, Foster, Schwab, Courtney), South Korea (Humphreys, Osan,
Casey, Carroll, Yongsan), Guam, Hawaii (Pearl Harbor, Schofield, Kaneohe),
Alaska (Elmendorf-Richardson, Eielson, Fort Wainwright, Eagle River).

### `cad-us-east` → `us-east.json`
Fort Bragg/Liberty, Camp Lejeune, NAS Oceana, Norfolk, Virginia Beach,
Quantico, Fort Belvoir, Annapolis, Aberdeen, Fort Drum, West Point,
Fort Jackson, Parris Island, Charleston, Fort Stewart, Fort Benning/Moore,
Fort Campbell, Fort Knox, Wright-Patterson, Dover, Langley, Eglin,
Pensacola, Jacksonville, Mayport.

### `cad-us-west` → `us-west.json`
Fort Carson, Peterson, Air Force Academy, Colorado Springs HQ, Fort Riley,
Fort Leavenworth, Offutt, Lackland, Fort Hood/Cavazos, Fort Sam Houston,
Fort Bliss, Fort Sill, Fort Irwin, Camp Pendleton, Twentynine Palms, San
Diego, Travis, Beale, Lewis-McChord, Kitsap, Fairchild, Mountain Home,
Malmstrom, Ellsworth, Minot, Grand Forks, Nellis, Hill.

### `cad-role` → `role.json`
The non-geographic axis. Rotate: "Associate Field Staff", "Limited Term
Ministry Staff", "hospitality house director", "Cadence Student Ministry",
"Field Leaders", "Area Director", intern, SkillBridge, "newly appointed",
mobilization, headquarters, "cadet ministry", academy, retired/emeritus,
"Adult Ministry", "Single Adult", chapel. Then spend at least four
searches on **`-surname` exclusion sweeps** — they were still producing at
the end of wave n, and this slice is where to push them hardest.

## Do not re-buy

Wave n's 18 queries are in `hunt_coverage` under `w2026-09-10n`. The
already-mined qualifiers were: Germany; Japan/Okinawa/Korea; hospitality
house Texas; student ministry campus; Italy/Spain/England/Europe; Colorado
Springs home office; Air Force Academy/West Point/Annapolis cadets;
Alaska/Washington/California base; North Carolina/Virginia/Fort
Bragg/Norfolk; Georgia/Florida/Kansas/Illinois/Ohio/Missouri; "Associate
Field Staff" OR "Limited Term Ministry Staff"; and two exclusion sweeps
covering Jessen, Vincent, Huisjen, Stephenson, Schroeder, Kinney, Bloker,
Jentink, Sprague, Argueta, Rozmiarek, Good, Amor, Walton, Ellgen, Bradley,
Caudle, Auldridge, Kelly, Fryman, Odom, Graham.

Go **narrower** than those — individual base names rather than country
names. We hold 142 people; the held list is a PLANNING HINT, NEVER A
FILTER. If you find a person, emit them. The orchestrator dedupes.

## Two domain-specific cautions

- **Two unrelated Sprague households exist on this domain.** Benjamin and
  Anna Sprague at `/missionary/benjamin-sprague/`, and Duncan and Angie
  Sprague at `/missionary/sprague/`. Never dedupe Cadence people on
  surname.
- **Split couples on the TITLE, never the slug.** See the standing rule —
  a two-name slug can outlive one of the two people.

## Everything else

Follow `tools/hunter/prompts/enumeration.md` exactly. Never cite a
search-results URL or someone else's page; children are not missionaries;
anonymized or initials-only people go to `needs_review`; never record or
infer demographic or identity attributes; log queries that found nothing;
and **do not state a count in your closing message.**
