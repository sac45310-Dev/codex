# Wave w2026-09-11t — Wycliffe Bible Translators

**Dispatched:** 4 agents (t-png, t-africa, t-americas-europe, t-roles), 18 searches each = 72.
**Found:** 302 unique people. **Loaded:** 291 · **Withheld:** 11 · 69 coverage rows · 6 negatives.
**Yield: 4.2 new people per query** — the best rate since the FOCUS seam, and three times the 1.3–1.4 retirement line.

Of the 291 loaded: 200 high confidence (score 9), 91 medium (score 7), 14 carrying a tenure-check note.

## This agency was written off in error, and the error is now traceable

`hunt_negatives` id 322 recorded Wycliffe as `platform_not_person` in w2026-09-10n:
*"the surface is not readable… giving is keyed by a Missionary ID, the opaque-ID
pattern."* Half of that was right. What it missed is that **a bare
`site:wycliffe.org/partner` query returns only the paginated directory** — you
have to add a qualifier before the per-person pages appear at all. One probe
with `site:wycliffe.org/partner <country>` surfaced seven named pages
immediately.

The negative was amended rather than deleted, so the reasoning stays visible.

## The pattern

`wycliffe.org/partner/<slug>`, with **at least nine slug shapes on one site**:

| shape | example |
|---|---|
| surname | `/fix`, `/yee`, `/beachy` |
| surname plural / family | `/Gossners`, `/moefamily`, `/CampbellFamily` |
| both first names | `/zakandlaura`, `/devinandcharity`, `/billyandmegan` |
| hyphenated | `/bryan-lori-jones`, `/kris-susan-toler` |
| initials | `/LHKrause`, `/jpw1990`, `/TAW05`, `/dstroyer` |
| descriptive vanity | `/everytribe`, `/fasterandfarther`, `/servantlibrarian`, `/thefivehive`, `/withthedriggers` |
| opaque hex ID | `/D26D32`, `/A18F31`, `/ve85e1` |
| full UUID | `/88883698-F2F4-4F68-9501-BBE6B51CE18F` |

Two consequences were written into the brief as graded rules, and both held:

- **Slug guessing is useless here.** No agent spent budget on it.
- **The surname is frequently absent from the URL.** `/partner/zakandlaury` is
  the O'Learys, `/partner/hamelitz` is the Pitchers. Those grade `high` — the
  slug is the couple's own vanity URL and the title names them in full. The
  opaque hex and UUID pages grade `medium` regardless, which is where 91 of the
  291 sit.

## Geographic slicing worked here — unlike last wave

Wave s split Reach Beyond two ways geographically and **38 of 56 names collided**.
Here four agents overlapped on only **25%** (342 rows → 302 unique). The
difference is that Wycliffe puts the country in the page snippet, so the search
engine can actually discriminate on it. The rule generalises: **slice by
geography only when the geography appears in the indexed text**, not merely
because the agency has regions.

## Withheld — 11 people, and why

Six retiree-shaped records, following the trap first documented at Baptist
Church Planters and Reach Beyond:

- **Bob & Dallas Creson** — "SIL Director 1989-1994", a closed historical role
- **Bob & Marilyn Busenitz** — "Indonesia Balantak 1980-2010"
- **Debbie Hatfield** — "1990-2019 service in Cameroon, Benin, Togo, Ghana"
- **Mike & Eve Brooks** — the agent itself flagged retired status
- **Steve & Lorrie Wittig** — verified by hand: "*had* the privilege of being
  part of Bible Translation for 35 years", past tense

**A closed date range is not by itself retirement.** Paul & Sonja Gross show
"Burkina Faso 1995-2008, **now Orlando headquarters**", and Steve Quakenbush's
page shows 1984-2008 and 2013-2017 but he currently directs SIL Global's
Spiritual Life Team. Both were kept. The signal that matters is a closed range
*with no current role stated*. My first screen missed all six of these because
it searched for "retired" and "N years" and not for date ranges — worth
recording, because it is the kind of gap that silently passes bad records.

The eleventh is different: **Alex & Patty Larkin, `/partner/alex`**, withheld as
`unverified_citation`. Three agents emitted them, but two independent searches
failed to surface that page or connect a Larkin couple to Wycliffe. It is the
one record in this wave whose existence is in doubt.

## Verification actually performed

Because 302 records from 72 searches is a suspiciously good return, I spot-checked
the citations rather than trusting them. Thirteen URLs were confirmed live with
matching titles, including four opaque hex IDs: `/D26D32` (Rosendall),
`/ve85e1` (Parker), `/zfamily` (Zielinski), `/wamplus` (Buchanan),
`/steve-janice` (Quakenbush), `/797465` (Busenitz), `/C6464A` (Wittig),
`/moefamily`, `/zakandlaura`, `/devinandcharity`, `/fix`, `/Gossners`, `/A18F31`.
The agents are citing real pages, not inventing them.

One caution for whoever reads the counts: **agent prose counts were wrong again**
— africa claimed 94 and wrote 86, roles claimed 142 and wrote 132. The
"do not summarise your counts" rule in the template exists for exactly this and
is still being ignored. Trust the files, not the closing messages.

## Not exhausted

163 distinct person-pages were reached. The directory paginates past `?page=127`.
Whatever the true roster size, search has touched a fraction of it, and the
qualifier space is nowhere near spent — country, language project, role and
centre names all still produce. A second Wycliffe wave is the highest-value
dispatch available, and unlike most continuations it is not a decay bet: the
constraint here is query coverage, not a shallow roster.
