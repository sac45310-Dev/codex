# Wave w2026-09-11x — budget-limited continuations

Every continuation this project has run until now has decayed: Cadence 0.69,
Wycliffe 0.35. So this wave is built on a rule wave u produced:

> **A continuation is worth running only when the first pass was cut short by
> BUDGET, not when it was cut short by the INDEX.**

These four agencies were selected by dividing people found by queries spent.
All four stopped because the agent ran out of searches, not because the search
engine ran out of pages.

| agency | held | queries spent | people/query |
|---|---|---|---|
| Baptist Missions to Forgotten Peoples | 61 | **11** | **5.5** |
| Every Nation | 40 | **9** | **4.4** |
| Baptist Church Planters | 38 | **12** | 3.2 |
| Baptist International Outreach | 17 | **6** | 2.8 |

For comparison: Wycliffe had 72 queries spent before its continuation, Young
Life 67, WWNTBM 74. Those are index-limited and are NOT in this wave.

## Confirmed patterns — mine them, do not look for them

- **BMFP** — `bmfp.org/missionaries/<slug>`. Wave q's agent was still returning
  new people on its tenth exclusion sweep when budget ran out. This is the
  single best continuation candidate in the database.
- **Every Nation** — `give.everynation.org/donate/<first>-<last>`, second shape
  `/category/missionaries/<last>-<first>`. Couples use
  `/donate/<first>-and-<first>-<surname>`. The org states **324 cross-cultural
  missionaries** plus campus staff across 1,405 campuses; only 40 are held.
- **Baptist Church Planters** — two surfaces:
  `give.bcpusa.org/missionary/<slug>` and `bcpusa.org/wpfc_person/<slug>/`,
  the latter mixing named and opaque numeric slugs.
- **Baptist International Outreach** — `biomissions.org`, per-person pages.

## Traps carried forward, by agency

- **BCP has TWO retiree/volunteer traps.** Retirees are supported *by* the fund
  rather than raising support, and unpaid council members sit on the same
  `give.bcpusa.org` surface. Neither is a prospect. Withhold both.
- **BMFP and BIO are independent Baptist boards**, so the BBFI age lesson may
  apply: look for approval or start dates, and treat a pre-1990 date with no
  current-activity statement as `needs_review`, not a record.
- **Every Nation**: split couples on the TITLE. One known slug typo —
  `/donate/yujiko-takagi` serves "Yujiro and Natsuko Takagi"; the TITLE is
  authoritative over the slug.

## Universal rules, not optional

- Never guess a slug. Rotate qualifiers and read what returns.
- Opaque numeric or hex IDs grade `medium`, always.
- A first-name-only or initials-only entry is a withheld surname →
  `needs_review`, never emitted, never resolved from another source.
- Children named on a profile are not missionaries.
- Never cite a paginated directory or `?page=N` URL as a `personal_page`.
- **Exclusion sweeps: 8–10 surnames per query, rotated.** Past about a dozen
  the engine silently drops the operators and re-serves excluded names; an
  identical result set is the stop signal.

## Slices

- **x-bmfp** — BMFP only. You have the largest budget-to-roster gap here; spend
  it on exclusion sweeps and role/field qualifiers.
- **x-everynation** — Every Nation only. 324+ cross-cultural missionaries and a
  separate campus-missionary population; rotate campus names, countries and
  roles.
- **x-bcp** — Baptist Church Planters, both surfaces.
- **x-bio** — Baptist International Outreach, plus Bible Baptist Mission
  (`biblebaptistmission.org`, 16 held, 5 queries spent) if BIO runs dry.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
