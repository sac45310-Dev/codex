# Wave w2026-09-10k — untouched agencies

**Dispatched** 2026-09-10. Four agents, 72 searches, **419 people loaded**.
Three agencies, all of which held **zero** records before this wave.

## Result

| agent | org | searches | people | new-people/query |
|---|---|---:|---:|---:|
| focus-a | FOCUS | 18 | 99 | **5.5** |
| focus-n | FOCUS | 18 | 66 | 3.7 |
| spo | Saint Paul's Outreach | 18 | 49 | 2.7 |
| bmm | Baptist Mid-Missions | 18 | 206 | 11.4 *(see note)* |
| **total** | | **72** | **419** | **5.8** |

420 raw records, 1 cross-agent duplicate, 0 dropped at audit. 411 high /
8 medium confidence. All Tier A, all `personal_page`.

**The BMM number is not comparable to the others.** `bmm.org/families/…`
pages are *couple* pages: 116 pages carried 206 support-raising adults.
The like-for-like figure is 6.4 pages per query. Quoting 11.4 against
FOCUS's 5.5 would be comparing people to pages.

`focus-a`'s 5.5 is the highest genuine per-query rate the project has
recorded. Every rate here clears the retirement line (≈1.3–1.4/query) by
a wide margin.

## Surfaces

Verified by 7 searches *before* dispatch, which is why every slice paid:

- **FOCUS** — `focus.org/missionaries/<first-last>`. ~900 missionaries;
  the org states all of them raise 100% of their own support.
- **Saint Paul's Outreach** — `spo.org/support-<first-last>`, reachable
  from a find-a-missionary directory.
- **Baptist Mid-Missions** — `bmm.org/families/<surname-first1-and-first2>`.

## Rejected before dispatch

- **NET Ministries** → `hunt_negatives` / `platform_not_person`. One
  shared campaign page, and the people are 9-month young adults raising a
  one-off ~$7,000 goal — weak ICP fit independent of the enumeration
  problem.
- **ABWE** → `hunt_targets`, **not** a negative. Its missionaries do raise
  support; no readable per-person slug surfaced, so an agent could not get
  past `staff_directory` grade. Revisit if a pattern turns up.
- **Chi Alpha** → `hunt_targets`, **not** a negative. Federated: no
  national giving surface, each district runs its own. That is a wave of
  its own, not a slice inside this one.
- **FCA** — already in `hunt_negatives`.

Two of those three are recorded as deferred rather than rejected on
purpose. "We could not find the surface" and "this org is not our buyer"
are different facts, and collapsing them into `hunt_negatives` would
permanently hide two live agencies.

## Fabrication check

Both FOCUS slices and SPO produce guessable `<first-last>` slugs, so a
model could in principle invent plausible people. Checked and cleared:

- FOCUS surnames are rare and non-generatable — Carayiannis, Skerjanec,
  Kasprowicz, Rybicki, Weinkopf, Hejkal, Stimach, Ceja-Lopez,
  Franceschini, Paiement.
- Slug capitalization and shape are inconsistent in ways a generator
  would not reproduce (`joshuaholtman`, `samanthakopecky`,
  `zoitos-carayiannis` for a John, `aj-dalida` for an Anthony).
- `samuel-sproule` corroborates a profile verified independently at
  dispatch time.

## People-protection

BMM's 8 `needs_review` records are all pages giving a first name only or
a withheld surname — sensitive-region workers. Correctly withheld, none
emitted, and they should not be chased in a later wave.

No demographic or identity attribute was recorded for any person, per
standing rule.

## Audit defects

`spo` returned **zero** defects — the cleanest agent output of the
project. The other three carried only the usual minor prose/file count
drift; no bad citations, no search-results URLs, no other-person pages.

## Coverage recorded

70 unique queries + 326 URLs = 396 rows under `w2026-09-10k`.

## What this changes

Three agencies moved from zero to `partial`:

| org | held | est. pool | verdict |
|---|---:|---:|---|
| FOCUS | 164 | ~900 | **under a fifth mined — go again** |
| Baptist Mid-Missions | 206 | large | slice only; surname and field axes both open |
| Saint Paul's Outreach | 49 | unknown | directory not enumerated to the end |

Database now holds 3,842 approved people.

The wave confirms the pattern the last six waves established:
**verify the per-person surface first, then dispatch.** Every untouched
agency where the surface was confirmed in advance returned 2.7–5.5 new
people per query. Continuations of already-mined agencies have been
decaying to 0.3–0.8. The next wave should be untouched agencies again,
or a second pass at FOCUS, which is the rare case of a rich surface that
is nowhere near exhausted.
