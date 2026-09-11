# Wave w2026-09-11q — unprobed independent Baptist sending agencies

**Dispatched:** 4 agents (baptist-a, baptist-b, baptist-c, baptist-d), 18 searches each.
**Loaded:** 146 unique people across 7 agencies · 72 coverage rows · 8 negatives · 6 new hunt_targets (ids 834–839).
**Yield:** 146 net-new people / ~72 queries = **2.0 new people per query** — well above the 1.3–1.4 retirement line, and the second-best wave since the FOCUS seam.

## Why this wave was dispatched

Every continuation wave since k has decayed (Cadence came back at 0.69/query in wave o). Every *verified-then-dispatched untouched agency* has returned 2.7–8.0/query. The independent-Baptist sending-board world was the largest block of agencies in `hunt_targets` with no coverage rows at all, and the agencies are structurally alike: small boards, WordPress sites, per-missionary pages built for deputation.

## What was found

| agency | people | surface |
|---|---|---|
| Baptist Missions to Forgotten Peoples (`bmfp.org`) | 61 | `/missionaries/<slug>/` — clean, deep, exclusion sweeps kept producing to the tenth query |
| Baptist Church Planters (`bcpusa.org`) | 38 | two surfaces: `give.bcpusa.org/missionary/<slug>` and `bcpusa.org/wpfc_person/<slug>/` |
| Baptist International Outreach (`biomissions.org`) | 21 | per-person pages, deaf-ministry and Latin America concentrations |
| Bible Baptist Missions (`biblebaptistmission.org`) | 13 | "Where we are" field list |
| Baptist Faith Missions (`bfmnow.org`) | 5 | per-person, Peru/Brazil |
| Prayer Baptist Missions (`prayerbaptistmissions.com`) | 4 | `/my-profile/pbmi/<slug>` — partially login-gated |
| Baptist Bible Fellowship International (`bbfimissions.com`) | 4 | `/missionary/<slug>` |

## The headline is not the 146 — it is BBFI

`bbfimissions.com` is the **biggest untouched seam since FOCUS**. Recorded as a hunt_target at priority 94.

- **700+ missionaries in 80+ nations.** Four taken. Eight held in total.
- Per-person pages at `/missionary/<slug>`, titled "First and First Surname" — so couples split cleanly, and on this agency's demographics that roughly doubles the person count per page.
- **Two slug shapes are used interchangeably**: `nolan-and-janay-letourneau` alongside `wyatt-michael-and-cristy`. Slug guessing therefore misses about half the site by construction, which is exactly what happened to the agent — it went 0-for-8 on guessed names and had to fall back on qualifier rotation.
- **`bbfimissions.com/missionaries?show=all` is the single highest-value fetch target in the project.** One page, the whole roster.

## Traps this wave surfaced

- **BBFI's "Heroes of the Faith" path is a death flag.** Pages under it are memorials. Treated as such, and *surviving spouses were also withheld* — a memorial article is evidence about the deceased, not evidence that the survivor is currently on staff and raising support.
- **Betty Camp withheld** on a legacy-URL vs current-page conflict.
- **BCP retirees are supported *by* the fund, not raising support** — the giving page looks identical to an active missionary's. Withheld.
- **BCP council members are unpaid volunteers** and also sit at `give.bcpusa.org`. Withheld.
- BCP's `wpfc_person` surface mixes named slugs with opaque numeric ones on the same site; graded per record, not per domain.

## Agencies closed out (8 negatives recorded)

Evangelical Baptist Missions (defunct) · Continental Baptist Missions (`gocbm.org`, no enumerable slugs) · Independent Faith Mission (`ifmnews.com`, JS-rendered) · Berean Mission (zero indexed content) · Baptist Mid-Missions Canada (no independent domain) · Beacon IBM (names nobody) · Vision Baptist (no per-person children) · Prayer Baptist (partial — login-gated beyond the four taken).

## Recommendation

BBFI justifies a dedicated multi-agent wave on its own, but **only after a fetch pass** — search alone cannot beat the dual-slug problem, and a second search wave would burn budget rediscovering the same ~8 pages. Until egress opens, BMFP-style agencies (deep `/missionaries/` trees, single slug shape) are the better spend.
