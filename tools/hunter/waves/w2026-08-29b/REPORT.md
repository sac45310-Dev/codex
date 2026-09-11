# Wave w2026-08-29b — report

Date: 2026-08-29. Runtime: Claude Code remote session, 16 roster agents on
Haiku 4.5 (search-only technique; WebFetch egress-blocked).

## Results

- **240 unique people found; 177 net-new imported** into `sales.scout_candidates`
  (`source_query LIKE 'hunter:w2026-08-29b%'`), min fit 4, junk single-token
  org names filtered.
- **213 coverage rows** written to `sales.hunt_coverage` (queries + outcomes),
  so none of this ground is ever searched again.
- **12 records** parked in `needs_review.json` for the verifier.

## Headcounts (people now on roster per org)

| Org | People |
|---|---|
| Ethnos360 | 40 |
| Young Life | 36 (97 total incl. pre-existing) |
| World Gospel Mission | 30 |
| Youth for Christ USA | 24 |
| Mission Aviation Fellowship | 20 |
| Christar | 18 |
| Cru | 14 |
| Wycliffe Bible Translators USA | 12 |
| Serge | 8 |
| The Navigators | 5 |

## Roster status updates

- `rostered`: MAF, Ethnos360.
- `exhausted` (partial — large org, search-only): Cru, Young Life, Wycliffe,
  YFC, Navigators, Serge, Christar, WGM.
- Reset to `unrostered` (agents budget-starved, not actually exhausted):
  Pioneers, SIM International, One Mission Society, Reach Beyond,
  Seed Company, Christian Health Service Corps, East-West Ministries
  International, Encompass World Partners, Global Gates Network,
  Liebenzell Mission USA, Mesa Global, New International,
  WEC International USA.

## What went wrong / lessons

1. **Session-wide WebSearch cap (~200 calls)**: 8 of 16 agents launched after
   the cap was hit and returned zero. Standing rule now: ≤ 8 search-heavy
   agents per session; scale via sibling cloud sessions with fresh budgets.
2. **WebFetch egress-blocked** in remote environment: prompts must say
   "WebSearch only, mine snippets".
3. Batch SQL files must be generated with `--batch-size 40` to stay under the
   64KB read cap; large coverage SQL split into a/b parts.

## Outstanding for next wave

- 13 unrostered orgs above.
- 6 prospector niches not yet launched: secular continuation, medical
  missions, sports ministry, YWAM bases, veteran/military family,
  food banks southeast.
- w2 verifier pass (sample + the 12 needs_review records).
