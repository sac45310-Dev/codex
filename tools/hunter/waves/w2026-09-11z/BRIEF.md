# Wave w2026-09-11z — Africa Inland Mission (AIM)

`usgiving.aimint.org`. **Fresh target: zero people held.** AIM was founded in
1895 and is one of the largest Africa-focused sending agencies.

## Two-question probe, both answered before dispatch

1. *Does a per-person surface exist?* **Yes** — confirmed below.
2. *Do we already hold these people?* **No** — `scout_candidates` has zero rows
   on this domain, and `hunt_negatives` has none either.

(That second question is in this brief because skipping it wasted a whole wave
twice this session — Avant in wave s and Encompass in wave y.)

## Pattern — confirmed

**`usgiving.aimint.org/missionary/<numeric-id>`**

Verified, with titles as search returned them:

| URL | title |
|---|---|
| `/missionary/1043880` | Colin and Rebecca McDougall |
| `/missionary/102093` | Paul and Elizabeth Makau |
| `/missionary/157620` | Shara Tanner |
| `/missionary/120320` | Russell and Nicole Smith |
| `/missionary/1011150` | Andrew and Margaret Andersen |
| `/missionary/1019270` | Roger and Shirley Brown |
| `/missionary/1057500` | Paul and Virginia Tanner |
| `/missionary/181475` | Nathan and Nicole Hunter |
| **`/missionary/1061450`** | **"Retiree - Stephen and Debbie Wolcott"** |

Index at `usgiving.aimint.org/missionaries`. Working query shape:
**`site:usgiving.aimint.org <qualifier>`**.

## EVERY RECORD FROM THIS AGENCY IS `medium`. No exceptions.

The slug is an **opaque numeric ID**. It never ties the page to the name — the
name comes only from the title. That is exactly the case the confidence table
calls `medium`, and it is the rule that had to be applied retroactively to 128
BIMI, 27 GEM and 5 InterVarsity records across earlier waves.

Do not grade anything `high` here, however clear the title is. If you find
yourself wanting to, re-read this paragraph.

## The retiree trap is LABELLED here — a gift, so use it

`/missionary/1061450` is titled **"Retiree - Stephen and Debbie Wolcott"**.

AIM puts the word **Retiree** in the page title. No other agency in this
project has done that. It means the trap that has cost withheld records at
Baptist Church Planters, Reach Beyond, BBFI and Wycliffe is, here, simply
readable.

- **Any title beginning "Retiree" → do not emit.** Put it in `needs_review`
  with the title quoted. Retirees are supported *by* the fund, not raising
  support, so they fail Tier A.
- Also watch for the unlabelled version: a long closed date range with no
  current assignment. "Served 1982–2010" with nothing current is the same
  thing without the label. A closed range *with* a current role is fine —
  Andrew and Margaret Andersen show "30 years... current assignment began in
  2015", which is active.

## Other rules

- **Split couples on the TITLE.** Couples are the norm here ("Colin and
  Rebecca McDougall" is two people sharing one page).
- **Do not emit children.**
- **First-name-only or initials-only → `needs_review`, never emitted, never
  resolved from another source.** AIM works in several sensitive areas.
- Do not cite `usgiving.aimint.org/missionaries` — that is the directory, not
  a page about a person.
- Tier A throughout. AIM's own serve page lists teachers, administrators,
  theological educators, healthcare workers, engineers, agriculturalists,
  aviators, media/IT specialists, dorm parents and ESL teachers — **all of
  them support-raised**. Do not tier anyone down on job function.

## Slices — non-overlapping by country

- **z-east** — Kenya, Uganda, Tanzania (AIM's historic core), plus Rift Valley
  Academy, Africa International University, Tumaini Counseling Center.
- **z-central-west** — DR Congo, Central African Republic, Chad, Sudan, South
  Sudan, Nigeria, Niger, Senegal, Guinea, Ivory Coast, Ghana.
- **z-south-islands** — South Africa, Mozambique, Madagascar, Namibia, Botswana,
  Zambia, Malawi, Lesotho, Comoros, Mauritius, plus "unreached people groups".
- **z-roles** — no country qualifiers. Rotate: teacher, dorm parent,
  theological educator, healthcare, nurse, doctor, engineer, technician,
  agriculturalist, aviation, AIM Air, pilot, media, IT, business, ESL,
  church planter, disciple maker, member care, short-term.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
