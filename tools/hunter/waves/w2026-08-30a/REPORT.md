# Wave w2026-08-30a — report

Date: 2026-08-30. Runtime: Claude Code remote session, 20 Haiku 4.5 agents
(13 roster + 6 prospector + 1 verifier), search-only technique.

## Results

- **134 net-new people** imported into `sales.scout_candidates`
  (`source_query LIKE 'hunter:w2026-08-30a%'`) — Tier A 36, Tier B 40, Tier C 58.
- **86 new organizations** added to `sales.hunt_targets` (458 total).
- **155 coverage rows** written to `sales.hunt_coverage` (1,408 total) — this
  ground is never searched again.
- **35 negatives** reason-coded (90 total).
- All **13 orgs starved by wave 2's search cap are now covered**; 12 marked
  `rostered`, WEC International USA `exhausted`.

## Roster headcounts

| Org | People |
|---|---|
| Encompass World Partners | 17 |
| Christian Health Service Corps | 14 |
| Seed Company | 13 |
| Mesa Global | 13 |
| One Mission Society | 10 |
| New International | 10 |
| East-West Ministries International | 9 |
| Global Gates Network | 8 |
| Liebenzell Mission USA | 5 |
| Pioneers | 4 |
| SIM USA | 3 |
| WEC International USA | 3 |
| Reach Beyond | 2 |

Pioneers and Seed Company deliberately do not publish individual missionaries
(field security), so their counts are leadership/board only. That is a finding,
not a gap — do not re-hunt them for Tier A.

## Prospector yield (new candidate orgs)

Southeast food banks 21 · medical missions 16 · secular nonprofits 15 ·
veteran/military family 13 · YWAM US bases 12 · sports ministry 9.

## Verifier pass on wave w2026-08-29b

12 parked `needs_review` records adjudicated: **8 verified**, 1 still unclear,
3 rejected as `platform_not_person` (first-name-only listings on a campus
ministry page — not identifiable individuals).

## Data-quality corrections made during ingest

1. **Tier inflation.** The food-bank and veteran prospectors labelled 10
   nonprofit executives Tier A (personally support-raised). A senior title is
   not evidence of support-raising — retiered to C (leadership influencers) and
   B (one development VP), scores capped into the 4–6 band.
2. **Job postings imported as people.** The secular and YWAM prospectors
   returned 13 records whose "name" was an open role
   ("Director of Advancement - BELONG Partners") or a single token. Filtered out
   and recorded as `platform_not_person` negatives.

Both are recurring prompt weaknesses — fix in the prompt templates before the
next wave rather than in post-processing.

## Policy note

`do_not_pursue` is a manual-review field. Agents in this wave did not classify
any organization for it, and no individual's demographic or identity attributes
were recorded. See commit b987a97.

## Outstanding

- 434 orgs sit `unrostered` in `hunt_targets` — the next wave's queue, best
  prioritised by `tier_profile` and size rather than run end-to-end.
- 1 wave-2 record (`Isaac`, Navigators Belmont) remains unresolved.
