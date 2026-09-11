# Wave w2026-08-30d — report

Date: 2026-08-30. 8 Haiku 4.5 roster agents, search-only. Third wave on the
priority queue; first carrying the parent-org filter.

## Results

- **63 net-new people** imported (`source_query LIKE 'hunter:w2026-08-30d%'`).
- **47 coverage rows**; 2 orgs recorded as negatives.
- Running totals: **3,511 people · 1,533 coverage rows · 30 orgs rostered ·
  95 negatives**. Hot queue down from 20 to **12**.

| Org | People | Verdict |
|---|---|---|
| Atlanta Community Food Bank | 20 | rostered |
| Second Harvest Food Bank of Central Florida | 18 | rostered |
| Feeding Northeast Florida | 11 | rostered |
| YWAM San Diego/Baja | 6 | rostered |
| Harry Chapin Food Bank | 5 | rostered |
| Helping Hands Medical Missions | 3 | rostered |
| YWAM Maui | 0 | exhausted |
| YWAM Asheville | 0 | exhausted |

## Rule check: 4 violations in 63 records, all one class

All four were YWAM San Diego founders given `evidence_basis: org_policy` but
left at confidence "high" and score 8 — the rule caps org-policy Tier A at
medium/7 precisely because it is weaker than a personal giving page. Normalized
at ingest. The agent applied the new exception correctly in substance and only
missed the ceiling, which is a much smaller error than the tier confusion this
rule replaced.

One schema slip: the ACFB agent wrote a prose paragraph into `roster_verdict`
instead of a token. Normalized. Worth a schema `enum` if it recurs.

## The two food-bank waves are paying off differently than the YWAM ones

Secular food banks are the strongest yield so far — three of them produced 49
people between them, because they publish full leadership and board rosters.
But the tier mix is lopsided: **51 of 63 records are Tier C**, and only 6 are
Tier B development staff. Boards are easy to find and weak as prospects; the
development staff who would actually use DonorSend are thin on the ground.

Worth deciding before the next wave: a board-heavy org yields a big headcount
that flatters the numbers without improving the pipeline. Capping board members
per org (say 5) would keep the signal and cut the noise.

## YWAM bases have hit a wall

Maui and Asheville both returned zero named people despite confirmed bases with
~45 and ~50 support-raised staff. Neither publishes staff names. Combined with
Orlando and Tyler last wave (exhausted, unverifiable names), the pattern is
clear: **individual YWAM bases do not publish rosters**, and search-only
technique cannot reach them. San Diego/Baja was the exception because it hosts
public staff-profile pages.

Recommendation: stop spending roster budget on YWAM bases that lack a
`/staff-profiles` style page. Check for one with a single query before
committing an agent.

## Outstanding

- 12 orgs in the hot queue; 415 unrostered overall.
- Harry Chapin has two people both listed as current CDO (Haniff, Prifrel) —
  sources conflict; both imported at medium confidence, flagged here.
- 1 needs_review record (Jo Anna Bradshaw, capital campaign co-chair, staff vs
  board unclear).
