# Wave w2026-09-12b — International Students, Inc. (ISI)

## Verify-then-dispatch

**Do we hold these people?** No. FK 0, `target_org` 0 real matches, domain 0,
not in `hunt_negatives`. The four records that mention "international students"
are RUF-I, Cru and Modern Day people, not ISI. Genuinely unworked.

**Does the agency fund its own people?** Yes — this is the test wave
w2026-09-12a added to the template after SIL failed it, and ISI passes cleanly.
ISI's own site says donors can search for **any staff member's** donation page,
and staff pages live on ISI's own domain.

| shape | example |
|---|---|
| `internationalstudents.org/team/<firstname>-<lastname>/` | `/team/john-livingston/`, `/team/nancy-parlette/`, `/team/jeff-townsend/` |
| `internationalstudents.org/team/<surname>s/` — couples | `/team/alumbaughs/`, `/team/boyles/`, `/team/lashelles/`, `/team/woods/` |

`/team/` itself is the Campus Staff Archive. `/staff/`, `/give/`,
`/national-ministry/` and `/department-sites/` are directories and landing
pages, not people.

**Why this should work where SIL did not.** SIL person pages carried the name
and nothing else. ISI snippets carry the **city and state** ("Campus Staff in
Lancaster, KY", "in Clarksville, MD", "in Pocatello, ID") and the **role**
("Campus Staff", "local Campus Director"), and several state support-raising
outright ("raising support to step into her official role", "having ministry
partners to support her, both financially and in prayer"). Geography is a live
axis here. ISI reports staff on **677 campuses**.

## The trap specific to this agency

ISI's own text describes a Campus Director leading "staff, **ministry Reps and
volunteers**." Volunteers and Reps are not personally support-raised staff and
are not in ICP. This is the Encompass short-term problem in a new costume: one
`/team/` namespace serving two populations.

## Rules — all unconditional

1. **Emit only pages under `internationalstudents.org/team/`.** `/staff/`,
   `/give/`, `/national-ministry/`, `/department-sites/`, `/giving-tuesday/`
   and `/international/` are directories. No exceptions.
2. **A record is `high` confidence.** Both observed slug shapes carry the
   surname and the title names the person. No exceptions.
3. **A slug that does not contain the surname makes that record `medium`.**
   State the reason in `fit_reason`. No exceptions.
4. **`evidence_basis` is `personal_page` for every emitted record.** No exceptions.
5. **`fit_score` is 9 for a `high` record and 7 for a `medium` record.** Tier A
   throughout. No exceptions.
6. **A page identifying the person as a volunteer or a ministry Rep goes to
   `needs_review` and is not emitted.** Emit staff, campus staff, campus
   directors and area directors. No exceptions.
7. A couple page yields **two records**, one per named person, both citing the
   same URL. No exceptions.
8. A title giving initials only, a first name only, or a codename goes to
   `needs_review`, is never emitted, and is never resolved from another source.
   No exceptions.
9. A closed date range with no current role stated goes to `needs_review` as a
   suspected retiree. A closed range *with* a current role is fine. No exceptions.
10. **Never record or infer any individual's demographic or identity
    attributes.** No exceptions.

Record the city and state when the snippet gives them — they are in `city` and
`state`, not in the summary only.

## Axes — 24 queries each, 96 total

Geography is the primary axis because ISI puts it in the indexed snippet.

- **agent A — Northeast and Mid-Atlantic.** NY, NJ, PA, MA, CT, RI, NH, VT, ME,
  MD, DE, VA, WV, DC.
- **agent B — South and Southeast.** FL, GA, NC, SC, TN, KY, AL, MS, LA, AR, TX, OK.
- **agent C — Midwest and Mountain.** OH, MI, IN, IL, WI, MN, IA, MO, KS, NE,
  CO, UT, AZ, NM, MT, ID, ND, SD, WY.
- **agent D — West Coast, plus roles and the couple-slug shape.** CA, OR, WA,
  NV, AK, HI; then "Campus Director", "Area Director", "Campus Staff",
  "ministry partners"; then probe the plural-surname couple shape directly.

Do not use surname exclusion lists — the operator ceiling is ~10–12 terms and
they have hidden real people before. Emit everything that qualifies; the
orchestrator dedupes at ingest against all 6,694 person records held.

Report `new_people_found / queries_run`. Search titles, URLs and snippets only —
WebFetch is EGRESS_BLOCKED.
