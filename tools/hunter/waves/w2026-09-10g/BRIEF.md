# Wave w2026-09-10g — untouched agencies

Rendered from `tools/hunter/prompts/enumeration.md`. Five agents, 18 searches
each (90), plus 6 orchestrator verification searches. Model: Haiku 4.5.

## Why these targets

Ethnos360 is close to worked out — geography spent (24 country qualifiers),
role largely spent (73), last wave 2.7 new/query and falling. CMML is
search-capped. The remaining upside is untouched ground, which is what
verify-then-dispatch produced last time (FMC 3.7/query, MWBM 2.2, IBFI 2.1
from a standing start).

Selection ran against `hunt_targets`: unrostered, has a website, not in
`hunt_negatives`, and no `site:` query coverage on its domain. The
priority-56 tail of that list is a bulk import carrying a default score —
Air1, Baker Publishing Group and similar are not support-raised staff and were
ignored. What survived is campus ministries and small sending agencies, where
essentially every worker raises personal support.

## Verification (6 searches, orchestrator-run)

| target | pattern | depth signal |
|---|---|---|
| **Campus Outreach** | regional city sites (`cocolumbia.org/staff`, `coatlanta.org`, `cohouston.org`) plus `donate.campusoutreach.org/giving-search`, a national **"Donate to a Staff Member or Team"** directory | the giving-search lists dozens of regions — Athens Greece, Atlanta, Augusta and many more |
| **CCO (Coalition for Christian Outreach)** | `ccojubilee.org/staff/<slug>` — verified `/staff/gsalo` = Glenn Salo; campus pages at `ccojubilee.org/campus-detail/<school>` | ~100 campuses; CCO gives "in-depth support-raising training when you join staff" |
| **Avant Ministries** | `avantministries.org/missionary/<slug>` — verified `/missionary/j-jenkins` = Jessica Jenkins | founded 1892; members attend a "support raising boot camp" |
| **RUF** | directory pages only: `ruf.org/people/ministers/`, `ruf.org/people/staff/` | RUF reports 170 campus ministers, 49 campus staff, 176 interns — all support-raised |

**Campus Outreach is the strongest lead in the database right now.** We already
hold 19 people from cocolumbia.org against **one** spent query — 19 per query,
the highest ratio anywhere in our coverage data — plus 8 from coatlanta.org
and 8 from cohouston.org. Those were incidental finds, never mined.

**RUF is the weakest of the five.** No per-person page surfaced in two
searches, only directory indexes. It gets one agent because ~395
support-raised staff is worth 18 searches even at `staff_directory` /
`medium` evidence, but if the directories do not name people in snippets, say
so and stop early.

## Assignments

| agent | target | slice |
|---|---|---|
| `co-east` | Campus Outreach | regions/cities A–L |
| `co-west` | Campus Outreach | regions/cities M–Z and international |
| `cco` | Coalition for Christian Outreach | `ccojubilee.org/staff/` and campus pages |
| `avant` | Avant Ministries | `avantministries.org/missionary/` |
| `ruf` | Reformed University Fellowship | `ruf.org/people/` directories |

## Slug shapes — read the confidence rule against these

CCO (`gsalo`) and Avant (`j-jenkins`) both compress the first name to an
initial. **This is their normal convention, not anonymization** — the surname
is in the slug, so a record is `high` when the title gives the full name.
Do not confuse it with the initials-only pattern that signals a withheld
identity, which is when the SURNAME is truncated or absent (`john-jan-b`).

## Tiering

Campus ministry staff, CCO staff, RUF campus ministers and Avant missionaries
all raise personal support: **Tier A**. Do not downgrade someone to Tier B for
holding a support-function or office role — the w2026-09-10f wave got this
wrong across 210 records. Tier turns on being personally support-raised, not
on job function or location. Use Tier B only where a page shows someone is a
salaried employee who does not raise support.

## Anonymization

Avant and Campus Outreach both work in restricted regions. A page that
withholds a surname, uses initials only in place of a surname, or sits under a
sensitive/creative-access label goes to `needs_review`, never to `people[]`.

## Students are not staff

Campus ministries publish student leaders, interns and summer-project
participants alongside staff. Emit **staff and interns who raise support**.
Do not emit students, and if a page does not distinguish them, say so in
`fit_reason` and grade `medium`.
