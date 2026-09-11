# Wave w2026-09-10l — FOCUS, second pass

**Dispatched** 2026-09-10. Five agents, 92 searches, **287 people loaded**
(279 from agents, 8 recovered for free before dispatch).

## Result

| agent | slice | searches | new people | rate |
|---|---|---:|---:|---:|
| focus-campus-mw | Midwest / Great Plains campuses | 18 | 68 | **4.8** |
| focus-campus-west | West / Southwest / intl / digital | 18 | 66 | 4.7 |
| focus-couples | couple and family pages | 20 | 50 | 4.7 |
| focus-campus-east | Northeast / Mid-Atlantic / South | 18 | 59 | 4.1 |
| focus-rare-names | untried given names | 18 | 39 | 2.9 |
| *(orchestrator)* | *spouses on already-cited URLs* | **0** | **8** | — |
| **total** | | **92** | **287** | **3.1** |

Zero search-results URLs, zero malformed names, zero cross-file duplicates.
286 high / 1 medium.

**No decay.** Wave k took 164 at 5.5 and 3.7; this wave held 4.1–4.8 across
four of five slices. Continuations normally fall off a cliff here (RUF
2.9→0.76, CCO 5.0→0.28). It didn't, and the reason is that these were **new
axes, not deeper passes on the same one.** Wave k mined common first names
nearly flat; the campus, couple and rare-name axes had barely been touched.

FOCUS moves from **17% to 46% enumerated** — 451 of 981. Database total 4,129.

## The eight free people

Before dispatching anything, auditing the held set against its own citations
turned up **eight support-raising adults inside URLs we already had**.
`david-and-catherine-wentworth` had yielded Catherine but not David;
`jared-and-emily-burbach`, `collin-and-alexandra-likover`,
`benjamin-eliza-kelly`, `amber-peter-manfre`, `samuel-claire-harris` and
`brennan-lizzy-connelly` were each half-harvested the same way. And
`focus.org/missionaries/david-hickson` is titled *"David and Linda Hickson
Family"* — a one-name slug hiding a second person.

Zero searches. This is the Baptist Mid-Missions couple-page lesson from wave
k, which had been recorded and then not applied to FOCUS.

## Three page shapes, not two

The brief named two couple shapes. The agents found a third:

1. **slug names both** — `dan-jules-tully`, `andy-katie-foy`, `camden-marian-bole`
2. **slug names one, title names both** — `david-hickson` → "David and Linda
   Hickson Family"; `isaac-nieto` → "Isaac and Anna Nieto"
3. **slug is the bare surname** — `/missionaries/macsay/` → "Eric and Teressa
   Macsay"; `/chang/` → "Jimmy and Melissa Chang"; `/holversons/` → "Ethan &
   Alli Holverson"

Shapes 2 and 3 are invisible from the URL. The single highest-yield query of
the wave was searching the literal indexed title suffix `"Family - FOCUS.org"`,
which is the only thing that exposes them.

## What does not work here

Recorded so no future wave re-buys it:

- **Negative `-surname` exclusions do not work on this domain.** Two searches
  spent on them returned result sets *identical* to their unexcluded
  counterparts — every excluded surname came straight back. The standing
  method's depth technique should be dropped for FOCUS.
- **The Northeast is barren under campus-name search.** Boston College,
  Providence, UMass, UNH, Rutgers, Princeton, Villanova, Fordham, Syracuse
  and Catholic University produced ~2 people across four queries.
- Georgia, Georgia Southern, UCF, USF, UNC and NC State return third-party
  diocesan sites, while Georgia Tech and Kennesaw State index fine —
  **indexing is per-campus, not per-region.**
- Nebraska outside Lincoln, TCU, Cal Poly, Nevada-Reno, New Mexico State: nil.
- Austria returned campus and press pages only; the Graz/Vienna/St. Pölten
  cohort is likely indexed under German-language campus names. Concrete next
  step, not an exhausted domain.
- Digital Outreach never names its team in a snippet.
- Full institution names index far better than abbreviations
  (`"University of Wisconsin"` works, `"UW-Stout"` does not).
- Irish, Polish and African given names are empty — the Irish presence is via
  surnames. **Spanish and Portuguese given names were the richest name
  sub-axis by a wide margin.** Saint names are half noise: Therese, Cecilia,
  Clare, Kolbe, Xavier and Felicity are real missionaries; Gianna,
  Bernadette, Zelie, Perpetua, Faustina, Isidore, Pio, Frassati and Ignatius
  resolve only to quoted saints and program pages.

## People-protection

The children rule was added to the template on the strength of a single probe
snippet, and it fired repeatedly: the Schotts', Nietos', Ponds', Lucidos',
Wurths', Paoluccis' and Bocinskys' children were all named in snippets and
all excluded, with the exclusion written into the parent's `fit_reason` so it
is auditable rather than invisible. One genuine ambiguity — a third name in
the same series as two adults — went to `needs_review` instead of being
guessed at.

The rare-names agent hit the predicted trap exactly: one first name appeared
on this axis three ways at once — as a missionary's child, as a first-name-only
roster entry, and as a real missionary with her own page. Only the third was
emitted.

Nothing anonymized or initials-only appeared in the international slice.

## Dedup caught three same-person pairs

Deduping on name+URL alone would have created three duplicate humans, and
deduping more aggressively would have destroyed a real one:

- **Six flagged same-URL/same-surname pairs.** Five were name variants of
  people we hold (Tom/Thomas Manning, Becca/Rebecca Lasher, Sam/Samuel
  Fulbright, Anna Brooke/Anna Baquet, Claire Marie/Claire Rybicki). The
  sixth, **Grace Schott vs Thomas Schott, is a real second person** — the
  spouse on a shape-2 couple page. An automatic surname+URL merge would have
  silently deleted her. Flagged for review rather than auto-merged, which is
  why she survived.
- **Annie Lugo** appeared at two URLs (`/annie-blanchard`, titled "Annie
  Lugo", and `/annie-lugo`). Kept the clean citation, dropped the medium one.
- **Christina Augustine** and **Christina Augustine-Sanchez** are one person
  on one URL, emitted by two agents under two name forms.

## Agent honesty

`focus-couples` used **20 searches against a budget of 18**, lost count around
the thirteenth, caught it while reconciling its own coverage at write time,
and logged the overrun as its own `needs_review` entry rather than burying it.
The wave total is 92, not 90.

Several agents also withheld people they were confident about, because the
grading table said to: spouses named only in body text, with neither slug nor
title carrying them (Funderburk, Bremerkamp, Brisnehan, Broderick, Matson,
Hill, Ayers, Moran, Seibert). That is a systematic loss of likely Tier A
adults and it is flagged with URLs for a reviewer with fetch access. It is the
right call under a no-fetch rule and the wrong outcome; worth revisiting if
fetching ever becomes available.

## Coverage recorded

92 queries + 251 URLs = 343 rows under `w2026-09-10l`.

Six agent rows carried `kind:"campus"` and one `kind:"note"`, neither of which
the `hunt_coverage` check constraint allows; the underlying queries were
already recorded, so they were dropped rather than coerced. The repo's
`scout_import.py ingest-wave` would have written the prose ones straight in as
`kind='url'` with 1,000-character values, and kept **zero** people (its people
path expects a `fit_score` field this schema does not carry) — so the loader
was done by hand this wave. That tool needs a fix before it is used on this
output shape.

## Next

FOCUS is still open at 46%, and the campus axis — the workhorse — has covered
roughly 60 of 211 campuses. A third pass on the remaining campuses is the
highest-confidence work available. The dead ends above should be skipped, and
Austria retried in German.
