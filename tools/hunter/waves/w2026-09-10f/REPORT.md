# Wave w2026-09-10f — report

Four agents, 18 searches each (72), single target sliced by role family, plus
one orchestrator verification search.

## Loaded

**189 people**, all distinct, all Tier A. Ethnos360 now stands at **534 held
(522 Tier A)**, up from 345. Coverage: 73 queries, 105 URLs.

## Yield

Agents emitted 367 records. After dedup and correction:

| stage | count |
|---|---|
| raw records emitted | 367 |
| unique people (cross-agent dedup) | 299 |
| already held from earlier waves | 110 |
| **genuinely new, loaded** | **189** |

**2.7 new people per query.** Down from 4.7 in w2026-09-10e, when geography
was still fresh, but well above the 1.3–1.4 at which WGM and FMWM were retired
and about 2.5x CMML's capped rate.

The role axis worked. It was worth running, and it is now largely spent: 73
role qualifiers bought against the 13 that existed before this wave.

## The cost of continuing a mined domain

**110 of 299 unique people — 37% — were already in the database.** Four agents
searching the same domain from different angles converge on the same profiles:
Kathryn Kreiger surfaced from all four role families, and 49 names appeared in
more than one agent's file. That overlap is the structural cost of a
continuation wave and it should be assumed, not treated as a surprise, when
sizing the next one.

## Tiering: a systematic error, and the fact that settled it

The agents returned **210 Tier B against 157 Tier A**, and **23 people got
contradictory tiers from different agents** — Tom Carlton, Robyn Green, Dave
and Kim Field, Kathryn Kreiger and others were Tier A to one agent and Tier B
to another.

Two things were wrong:

1. Only **14 of 367** records had any home-office or executive signal in their
   role text, yet 210 were graded B. The agents were treating a *support
   function* ("Builder Support", "Member Care Support" — usually the spouse in
   a couple) as meaning *not support-raised*. Those are different things.
2. The brief's own rule ("field roles Tier A, home office Tier B") turned out
   to rest on a false premise.

One search settled it. Ethnos360 states that USA missionaries are responsible
to raise financial support covering their salary and ministry expenses, and
that **this applies to home office staff as well as those serving overseas**
(ethnos360.org/give/questions). Tier A turns on being personally
support-raised, not on being posted to a field.

So all 189 loaded records are Tier A, and the ~40 whose role text names a
home-office function carry that citation inline in `fit_reason` so the basis
is inspectable rather than assumed. This also means the **brief for the next
Ethnos360 wave should not repeat the field/home-office tier split** — at this
agency it is not a real distinction.

## Corrections applied at ingest

| count | correction |
|---|---|
| 112 | `evidence_basis` `job_title` → `personal_page`. `job_title` means the role alone implies the tier; these all cite a per-person profile page, which is stronger. |
| 8 | Tier B → A on the home-office finding above |
| 2 | Confidence → `medium` where the surname is absent from the cited URL (Haejung Sung, cited to her husband's blog — Korean spouses keep separate surnames; Imie Mark III) |
| 6 | Dropped as nickname duplicates of held records (Elli/Elisabeth Schlegel; Bing and Lolly Hare, already held as a combined entry) |
| 1 | Rosemarie Baghurst flagged `needs_human_review` — role text reads "Retired", so active support-raising is unconfirmed |

A first pass of the nickname dedup used surname-plus-first-initial and produced
false positives (Dwight Brown collided with the held Debbie Brown, Lincoln
Lilley with Levi Lilley). Tightened to exact normalized match plus the
combined-couple forms that appear in held records, which is what the six above
came from.

## Prose vs file, again

`eth-technical` reported "172 individual records" in its closing message; its
file contains 135. This is the defect the template's "Do not summarise your
counts" section exists for, and it recurred despite the instruction being in
the template the agent read. Worth considering whether the rule needs to move
from prose guidance to a schema-level omission.

## Open items

- The four `homes.ethnos360.org` records from w2026-09-10e are flagged
  `needs_human_review` (retirement-homes site; the Goddards may be retired).
- Rosemarie Baghurst, as above.
- 23 people carry a tier that one agent disputed; all are now Tier A on the
  verified org-wide rule, but the disagreement is recorded here.

## What is left at Ethnos360

Geography is spent (24 country qualifiers, four returning nobody) and role is
now largely spent (73 qualifiers). What remains untried: individual field or
tribe names, year-based blog qualifiers, and the `homes.ethnos360.org` and
`ethnos360aviation.org` subdomains — the latter returned nothing on a bare
`site:` search in an earlier wave. A third Ethnos360 wave should be expected to
fall below 2.7/query.
