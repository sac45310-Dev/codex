# Wave w2026-09-11s — unprobed international sending agencies

**Method: verify-then-dispatch.** Eight agencies were probed by the orchestrator
before any agent was spawned. Three have confirmed per-person surfaces and get
agents. Five do not and are recorded as negatives instead of being handed to an
agent to rediscover. Every agent below is mining a pattern that is *already
known to exist*.

## Confirmed surfaces

| agency | pattern | evidence |
|---|---|---|
| Reach Beyond | `reachbeyond.org/missionaries/read/<first>-and-<first>-<surname>[-N]` | `/read/charles-and-jeanie-jacobson-1`, `/read/martin-and-ruth-harrison-1`; index at `/missionaries/list` |
| InterAct Ministries | `interactministries.org/<surname>-<first>-<first>/` | `/allen-dave-becky/`, `/richardson-dennis-celesta/`, `/henry-dave/`; index at `/missionaries/` |
| Avant Ministries | `avantministries.org/missionary/<initial>-<surname>` | `/missionary/j-jenkins` titled "Jessica Jenkins" |

## Rejected before dispatch — do not work these

- **JAARS** — `jaars.org/staff-support?fund-code=John+Marselus+102192`. Query string plus fund code; not a citable per-person page.
- **Christar** — support-a-worker takes a numeric account number only. Also works predominantly among least-reached Muslim populations, so anonymization is the norm.
- **Team Expansion** — account-number keyed, and the org states plainly that *"many workers are serving in sensitive locations and appear using a codename."* Treat any Team Expansion name encountered elsewhere as protected.
- **e3 Partners** — `?fundraiser=e3partners-matt-brown`. Query-string keyed.
- **Global Frontier Missions** — staff do raise 100% support, but no per-person surface exists.
- **Pioneer Bible Translators** — giving is by project/fund designation; no per-person URL surfaced.

## Per-agency traps — read these before your first search

### Reach Beyond (agents s-rb-a, s-rb-b)
- **`reachbeyond.org/missionaries/retired` is a trap.** Retired missionaries are
  supported *by* the fund; they are not raising personal support and are not
  prospects. Their pages look identical to an active missionary's. This is the
  same trap that Baptist Church Planters set in wave q. Do not emit anyone
  reached through `/retired`.
- **A first-name-only slug is a withheld surname, not a short name.**
  `/missionaries/read/hannah` and `/missionaries/read/allen` are real pages.
  Reach Beyond serves North Africa / Middle East among its six regions. These
  people are unnamed on purpose → `needs_review`, never a record, even if you
  can infer the surname from elsewhere.
- **A trailing `-1` is a CMS collision suffix, not part of the name.**
  `charles-and-jeanie-jacobson-1` is the Jacobsons.
- Couples are the norm in the slug. Split on the **title**, not the slug.

### InterAct Ministries (agent s-interact)
- **The slug is SURNAME-FIRST**: `/allen-dave-becky/` is Dave Allen and Becky
  Allen. Titles render "Allen, Dave & Becky". Do not read `allen-dave` as a
  person named Allen Dave.
- **`interactministries.org/retired/` is the same retiree trap.** Skip it.
- **Siberia is a sensitive region.** InterAct works Alaska, western Canada and
  Siberia. Several Siberia workers are published with first names only. Those
  go to `needs_review`.

### Avant Ministries (agent s-avant)
- The slug is `<initial>-<surname>` (`j-jenkins`). **This is NOT anonymization**
  — the page title publishes the full first name ("Jessica Jenkins"), so combine
  slug and title and grade `high`.
- **But if the TITLE also withholds the name, that IS anonymization** →
  `needs_review`. Avant works unreached areas; expect some.

## Slices

- **s-rb-a** — Reach Beyond: Latin America (Ecuador especially, their historic
  field) and Europe/Eurasia.
- **s-rb-b** — Reach Beyond: Sub-Saharan Africa, Asia Pacific, North America /
  multi-regional. Do NOT work North Africa / Middle East as a slice — it is
  their sensitive region.
- **s-interact** — InterAct Ministries: all of Alaska and western Canada.
  Siberia to `needs_review` only.
- **s-avant** — Avant Ministries: all fields.

Budget: 18 searches each. Everything else follows
`tools/hunter/prompts/enumeration.md`, which is authoritative where this brief
is silent.
