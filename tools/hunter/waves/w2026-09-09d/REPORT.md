# Enumeration wave w2026-09-09d — mining the giving-URL patterns

Date: 2026-09-09. Six enumeration agents, 15 searches each (90 executed), each
assigned one agency whose per-person giving-URL pattern w2026-09-09c had already
found. The instruction was not "find missionaries" but "enumerate inside this
known pattern with rotating `site:` qualifiers" — the fetch-blocked substitute
for walking a paginated directory.

## Results

**297 people loaded, all Tier A**, every one citing a personal giving page.
That is roughly double the previous wave from the same six agencies.

| org | found | loaded | pattern mined |
|---|---|---|---|
| SEND International | 83 | 83 | `send.org/give/missionaries/<lastname>` |
| Resonate Global Mission | 77 | 77 | `resonateglobalmission.org/missionaries/<names>` |
| CMF International | 45 | 45 | `give.cmfi.org/donate/<name>` |
| Greater Europe Mission | 43 | 42 | `gemission.org/donatemissionary/<ID or name>` |
| Campus Outreach (5 chapters) | 29 | 29 | `co<city>.org/<name>` |
| Free Methodist World Missions | 26 | 21 | `fmwm.org/<region>/<lastname>/` |

Cumulative Tier A across the system is now **649**, from 191 before these two
waves.

## Enumeration beats discovery, once a pattern exists

w2026-09-09c spent its budget finding six URL patterns and returned 156 people.
w2026-09-09d spent the same budget mining those six patterns and returned 297.
The pattern is the durable asset; the enumeration against it is cheap and
repeatable. Qualifier rotation (region, country, role, then bare-prefix
subsets with `-lastname` exclusions to push past the result cap) is what makes
`site:` behave like pagination.

The two-phase split — **find the pattern, then mine it** — should now be the
standard shape for any sending agency, not a single combined assignment.

## Corrections applied before load

Agents are graded before they are trusted. Corrections this wave:

- **Campus Outreach — 6 records held out.** Five were surname-only fragments
  ("Barnett", "Lane") that a name field cannot honestly carry; one cited a
  giving slug belonging to a different person.
- **Greater Europe Mission — 27 records downgraded to medium confidence.**
  Their giving URLs are opaque numeric IDs (`/donatemissionary/23792/`), so the
  page confirms *a* supported worker exists at that ID but not that it is the
  named person. Real evidence, weaker link.
- **SEND International — 4 records held out on safety grounds, not quality.**
  Their giving slugs are deliberately initials-only, which is how agencies
  anonymize workers in sensitive regions. The evidence was sound; publishing the
  names would undo a protection the agency put there on purpose.
- **FMWM — 5 records held out.** They claimed `evidence_basis: personal_page`
  while citing `https://fmwm.org/`, the bare homepage. A homepage does not
  support a per-person support-raising claim.
- **Resonate — 1 name corrected.** "Sarah Aderemi" is Sarah Kluitenberg; the
  couple page `sarah-kluitenberg-and-dami-aderemi` had been split by giving both
  halves the second surname.

Three agents also overstated their counts in prose relative to their own JSON
(Resonate 73 vs 62, GEM 45 vs 43, CO 36 vs 35). The files are authoritative;
the prose is not. This is now a recurring enough defect class to be worth a
line in the prompt.

## Campus Outreach Atlanta: org rejected, people kept

CO Atlanta is a ministry of Perimeter Church, not an independent 501(c)(3) —
staff are Perimeter employees and gifts process through Perimeter's EIN. The
org is marked `rejected` / `too_institutional` and added to `hunt_negatives`.

Its people stay. The rule holds: **the individual's funding model decides, not
the org label.** A personally support-raised campus minister is a DonorSend
user whether or not the entity above them is separately incorporated.

## Coverage

87 distinct queries recorded against wave `w2026-09-09d` (61 found people, 23
none, 3 off-topic), so this ground is not re-bought. System coverage is now
2,064 rows.

## Where the bottleneck is

Search is no longer the constraint. **653 hunter-sourced people are pending
review** against 1,645 total. Two more waves of this yield will not help until
that queue moves — the next lever is triage throughput, not more agents.
