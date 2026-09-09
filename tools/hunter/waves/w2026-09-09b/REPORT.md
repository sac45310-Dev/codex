# Domain pass w2026-09-09b

Date: 2026-09-09. Four Haiku 4.5 agents, 72 searches, 142 organizations from
the local wave that had no website.

## Results

**90 of 142 resolved (63%). 52 honest nulls. Zero audit failures.**

| region | resolved | of |
|---|---|---|
| Midwest & Appalachia | 25 | 42 |
| Northeast & Pacific NW | 22 | 32 |
| Texas & Southwest | 22 | 37 |
| Carolinas & Georgia | 21 | 31 |

Rosterable organizations — unrostered with a website — went from 389 to
**479**. Total corpus 798 orgs, 1,977 coverage rows, 131 leads.

## The audit

Every resolved domain was checked mechanically for three failure modes:

- **no evidence URL** — 0
- **aggregator recorded as the org's own site** (GuideStar, ProPublica,
  CauseIQ, Charity Navigator, Facebook, Google Sites) — 0
- **same domain assigned to two different organizations** — 0

The 63% resolve rate is the honest number. A guessing agent would have
reported near 100%, and roughly a third of it would have been fiction that
looked exactly like fact.

## Where the no-guessing rule actually earned its keep

Six cases where an agent found a *plausible but wrong* organization and
returned null rather than attach the domain:

| looked for | found instead | verdict |
|---|---|---|
| City Rescue Mission (Nashville) | Nashville Rescue Mission | null |
| Downtown Rescue Mission (Nashville) | Nashville Rescue Mission | null |
| Colorado Canine Rescue | El Paso County Canine Rescue | null |
| Warriors and Families Organization | Upstate Warrior Solution | null |
| Community Immigrant Services | Raleigh Immigrant Community | null |
| Pass The Salt Ministries (SLC) | same name, Hebron OH | null |

Each of those would have been a domain that resolved to a real, wrong
organization — the worst possible outcome, because nothing downstream could
detect it. The Phoenix twins (`Phoenix Ministries Inc` /
`Phoenix Ministries 3 Inc`) were both nulled for the same reason.

## Two findings beyond the domains

- **Mission East Dallas And Metroplex appears closed.** Rejected as
  `defunct` rather than left in the queue.
- **Two Nashville rows are probably mis-attributed.** "City Rescue Mission"
  and "Downtown Rescue Mission Inc" have no Nashville presence;
  Downtown Rescue Mission is a Huntsville, Alabama organization and City
  Rescue Mission is a name shared across many cities. Nashville Rescue
  Mission — the real one — is already held separately. Both are **flagged in
  notes, not deleted**: there is no evidence they are fabricated, only that
  the city attribution does not hold. Confirm before rostering.

## Outstanding

- **53 organizations still have no domain.** Most returned genuinely nothing;
  a handful are Google Sites or directory-only, which means they have no
  conventional web presence and may not be worth rostering at all.
- Resolving these further would need a different technique than search
  snippets — the remaining ones are the hard tail, not more of the same.
