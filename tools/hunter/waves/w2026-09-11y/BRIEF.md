# Wave w2026-09-11y — Encompass World Partners

`encompassworldpartners.org` (formerly Grace Brethren International Missions).
**Fresh target.** Only two people held, both from a legacy row.

## Pattern — confirmed by orchestrator probe

**`encompassworldpartners.org/person/<slug>`**

Verified, with the page titles search returned:

| URL | title |
|---|---|
| `/person/charity-reist` | Charity Reist **#3641** |
| `/person/mike-and-letitia` | Mike & Letitia Yoder **#448** |
| `/person/will-and-emma` | Will and Emma Ferguson **#3202** |
| `/person/kya-bolding-3057` | Kya Bolding **#3057** |
| `/person/malachi-saunders` | Malachi Saunders **#321** |
| `/person/esn` | **E. & S. N. #3515** |
| `/person/cecil` | Cecil O'Dell |

Working query shape: **`site:encompassworldpartners.org/person <qualifier>`**.

**Every title carries a member number.** That is useful — it confirms you are
on a real person record rather than a story page — but the number is not part
of the name. Strip it.

**Four slug shapes, so do not guess slugs:**
`<first>-<surname>` · `<first>-and-<first>` (**no surname at all** —
`/mike-and-letitia` is the Yoders) · `<first>-<surname>-<number>` ·
initials (`/esn`, `/cecil`).

Where the slug carries no surname but the title does, grade `high` and say so
— same as the Wycliffe `/zakandlaura` case.

## TWO TRAPS, and the first one is new to this project

### 1. Short-term trip participants share the surface with career missionaries

This is the new one. `/person/` pages include people going on **short trips**,
not just career staff:

- *"Charity Reist — going to France in May and June 2026"* — a two-month trip.
- *"Malachi Saunders — has served on mission with Encompass twice in Central
  Asia"* — episodic, not resident.

Compare with clear career staff: *"Mike and Letitia Yoder served as Encompass
missionaries in Berlin, Germany from 1997"*, *"the Plaster family, serving in
France for over 20 years"*, *"Will and Emma Ferguson, joining the team in
Yamanashi, Japan for a six-year assignment"*.

**Why it matters:** a short-term participant does raise money, but for one
trip. They do not manage an ongoing personal donor base, which is what
DonorSend serves. **Emit career and long-term-assignment people. Put
short-trip participants in `needs_review` with the trip duration quoted**, and
say in `fit_reason` which signal you used.

Signals of a trip rather than a career: a date range of weeks or months, "going
to", "will serve this summer", "served twice", "intern", "apprentice",
"TeamXtreme", a named short-term programme. Signals of career: a start year
with no end, "joined the team", a multi-year assignment, a role title, "serving
for over N years".

If you genuinely cannot tell, that is `needs_review`, not a record.

### 2. Anonymized workers are present and visible

**`/person/esn` is titled "E. & S. N. #3515"** — initials only, for a couple.
Encompass works Central Asia among other fields. Initials-only and
withheld-surname entries go to **`needs_review`**, never to a record, and
**never resolve the name from another source.** A member number is not a name.

## Standard rules that still bind

Split couples on the **TITLE**, never the slug. Do not emit children. Do not
cite a `/story/` or `/stories/` page as a `personal_page` — those are
articles; if a person appears only in one, grade `staff_directory` / `medium`
or skip. Tier A throughout: Encompass missionaries raise personal support, and
that includes home-office and leadership staff — Mike Yoder is the Executive
Director and still on a `/person/` page.

## Slices

- **y-europe** — France, Germany, Spain, Portugal, Italy, Czech, Slovakia,
  Poland, Ukraine, Ireland, UK, Albania, Greece.
- **y-asia** — Japan, Thailand, Cambodia, Philippines, Indonesia, Vietnam,
  India, Nepal, and any Central Asia references (expect anonymization there).
- **y-africa-latam** — Central African Republic, Chad, Kenya, Nigeria, Burundi,
  Rwanda, Togo, Niger; plus Mexico, Brazil, Argentina, Peru, Dominican Republic.
- **y-roles** — no country qualifiers. Rotate: church planter, team leader,
  theological education, Bible institute, medical, nurse, teacher, MK
  education, community development, business as mission, member care,
  executive director, regional director, mobilizer, home office, "joined the
  team", "serving since".

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
