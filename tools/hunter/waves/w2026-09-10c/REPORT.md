# Wave w2026-09-10c — enumeration on three verified patterns

Date: 2026-09-10. Six agents, two each against Converge, World Gospel Mission
and One Mission Society — the three patterns confirmed by live search in
w2026-09-10b. Slices split by geography so siblings did not buy the same
queries twice.

## Results

**356 people loaded, all Tier A**, from 90 searches.

| org | loaded | Tier A now | evidence-weighted | score |
|---|---|---|---|---|
| One Mission Society | 177 | 187 | 181.8 | 99 |
| World Gospel Mission | 102 | 126 | 120.0 | 96 |
| Converge | 77 | 83 | 62.4 | 57 |

OMS and WGM are now the two highest-scoring accounts in the system, ahead of
Resonate (94) and SEND (88). Converge scores lower on the same raw volume
because more than half its records are keyed by numeric ID and carry medium
confidence — the weighting doing exactly what it was built for.

## Pre-launch check that changed the design

Before spending 90 searches, the three patterns were probed for whether they
were already exhausted. Of the records those probes surfaced: OMS 8 of 9 new,
Converge effectively all new, **WGM only 1 of 6 new**. That is why WGM's two
agents were split hard by region rather than pointed at the same space.

## Corrections applied before load

Six defects, none of which the agents reported themselves:

- **11 records held on safety.** Seven were a cross-agent conflict: the
  Africa/Asia agent flagged Guest, Batschelet and Kunkle as appearing in WGM
  sensitive/creative-access results and withheld them; the Americas agent
  emitted the same people as ordinary records. Four more were Converge couples
  whose slug withholds the surname (`david-laurie-r`, `john-jan-b`) while the
  agent supplied a full name anyway.
- **4 initials-only fragments** ("Brad M.", "Deb M.") emitted by conv-emea
  despite its own claim to have routed all of them to needs_review.
- **49 cross-agent duplicates.** The geographic slices leaked — Converge's two
  agents both returned Ariel Lee, Rebecca Par, the Mabialas and the Molines.
- **3 same-person-different-slug pairs**, where one agent found the name-slug
  URL and the other the numeric one. Kept the named form, dropped the numeric.
- **`?cookies=0` tracking parameters** in Converge slugs, which would have
  defeated URL dedup by making one page look like two.
- **One unverified slug.** A five-URL spot check of OMS verified four; `McFall2`
  returned nothing. Lowered to medium rather than dropped, and flagged.

## Where two agents disagree on safety, take the cautious one

The Guest/Batschelet/Kunkle conflict is the case worth remembering. One agent
saw a signal the other missed, and the cost is asymmetric: wrongly withholding
loses one contact, wrongly publishing undoes a protection an agency put in
place deliberately. All seven are held with the reasoning recorded in
`wgm-americas.json`, recoverable if someone checks their regions.

## Verification is now paying for itself twice over

w2026-09-10b caught three fabricated patterns before they cost a wave. This
wave caught eleven safety records and 49 duplicates before they entered the
database. Neither would have surfaced from reading agent summaries — five of
six agents again gave prose counts that disagreed with their own files
(OMS 122→96, Converge 37→41, WGM 56→58).

That defect is now universal enough to act on: **stop asking agents for a prose
count.** The file is the only number that has ever been right.
