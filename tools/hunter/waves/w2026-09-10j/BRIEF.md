# Wave w2026-09-10j — CCO and RUF on newly found surfaces

Four agents, 18 searches each (72), plus 2 orchestrator verification searches.

## Read this before assuming the wave is worth running

Both targets measured **below the retirement line** last wave: RUF 0.76
new/query on its third pass, CCO 0.28 on its second. The 1.3–1.4 range is
where WGM and FMWM were retired. On the axes already worked, a further pass
would be expected to return well under 0.5.

This wave is not another pass on those axes. Two searches confirmed **surfaces
that no wave has touched**, and the whole budget goes to them. If these also
come in under ~0.7, both orgs should be closed out.

## New surface 1 — `ruf.org/ministry/<campus-slug>`

Earlier waves concluded "ruf.org has no per-person pages" and moved to
givetoruf.org. That was true but incomplete: ruf.org has **per-campus ministry
pages, and they carry staff bios**. Confirmed live:

  ruf.org/ministry/university-of-california-berkeley-ruf-international/
  ruf.org/ministry/oklahoma-state-university/
  ruf.org/ministry/emory-university/
  ruf.org/ministry/kennesaw-state-university/
  ruf.org/ministry/clemson-university/
  ruf.org/ministry/university-of-minnesota/
  ruf.org/ministry/university-of-maryland/
  ruf.org/ministry/university-of-south-carolina/
  ruf.org/ministry/campus-staff

The bios are substantive — e.g. "Casey Cockrum, Director of Female Campus
Staff, came to know the Lord through RUF at Mississippi State"; a campus staff
member at UC Berkeley who graduated Florida Atlantic in 2012; one at Emory
from Forest VA who graduated UVA in 2014; one at Maryland who interned at
Kansas State 2024–2026. RUF runs ~170 ministries, so this is ~170 pages that
have never been searched.

**The slug is the CAMPUS, not the person.** Grade `medium` /
`staff_directory` and say so, exactly as with givetoruf.org campus codes.

**The real risk on this surface is partial names.** Those bios often introduce
someone by first name only. A first-name-only record is a hard-rule violation:
put it in `needs_review`, do not emit it. Only emit a person whose FULL name
you actually saw.

## New surface 2 — `ccojubilee.org/campus-detail/<school>`

CCO is **national**, not the PA/Ohio/mid-Atlantic organisation an earlier
brief of mine described. Confirmed campus pages include College of Charleston,
University of Delaware, **Fresno City College**, Arcadia University,
**UC Santa Cruz**, Franklin & Marshall, plus Pittsburgh, Duquesne, Slippery
Rock and Robert Morris. The out-of-region campuses were never searched
because my earlier campus list pointed the wrong way.

`campus-detail` pages describe the ministry and may not name staff. Their
value is as an **index**: enumerate them, then search
`site:ccojubilee.org/staff <campus>` for each campus not already worked.

## Spent — do not re-buy

RUF campus codes and personal slugs: see `waves/w2026-09-10i/BRIEF.md`; ~90
codes and ~110 personal slugs are spent, and last wave an agent wasted half
its budget on codes already listed as spent. **This wave nobody searches
givetoruf.org at all** — it is worked out. Stay on ruf.org/ministry.

CCO campuses already searched: Penn State, Boston College, Ohio State, West
Virginia, Duquesne, Geneva, Kent State, Slippery Rock, Temple, Drexel, Grove
City, Indiana University of PA, Pittsburgh, Robert Morris, Shippensburg,
Millersville, Waynesburg, Westminster, Washington & Jefferson, Akron,
Rutgers, Rochester, Buffalo, Carlow, Chatham, Ithaca, Syracuse. CCO surname
sweeps are **dead** — eleven consecutive batches returned nothing; do not
repeat that technique.

## Assignments

| agent | slice |
|---|---|
| `ruf-ministry-a` | `ruf.org/ministry/` campuses A–M |
| `ruf-ministry-n` | `ruf.org/ministry/` campuses N–Z, plus RUF-International ministry pages |
| `cco-national` | CCO staff at the confirmed out-of-region campuses |
| `cco-index` | enumerate `campus-detail` fully, then mine `/staff` for each campus it reveals |

## Tiering

RUF campus ministers, campus staff, area coordinators and interns, and CCO
staff, fellows and associates, all raise full personal support: **Tier A**.
CCO **volunteers** are not — role text containing "Volunteer" goes to
`needs_review`.

Do not emit students.

## The held list is a PLANNING HINT, NEVER A FILTER

Do not drop a person because their surname matches one we hold. Two people can
share a surname. Dedup is the orchestrator's job.
