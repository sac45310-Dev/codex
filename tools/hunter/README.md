# tools/hunter

Operating kit for the DonorSend Hunter Agent system. Full design:
`HUNTER_AGENT_PLAN.md` at repo root.

## Contents

```
prompts/prospector.md   discovery agent prompt template (Haiku 4.5)
prompts/roster.md       org-roster agent prompt template (Haiku 4.5, Sonnet escalation)
prompts/verifier.md     QA agent prompt template (Haiku 4.5)
schemas/wave_output.schema.json   the JSON every agent must emit
sql/wave_prep.sql       pre-wave exports (skip lists, coverage, unrostered targets)
```

Wave ingestion lives in `../scout-import/scout_import.py ingest-wave`.

## Database objects (created 2026-08-29, migration `create_hunter_agent_tables`)

| Table | Purpose |
|---|---|
| `sales.hunt_targets` | Org registry: roster_status, priority, headcount_found |
| `sales.hunt_coverage` | Every URL/query ever searched — including empty-handed ones |
| `sales.hunt_negatives` | Reason-coded rejects (see codes below) |

## ICP tiers (revised 2026-08-29)

| Tier | Who | Fit band |
|---|---|---|
| A | Personally support-raised individuals (missionaries, deputized staff, support-raised planters/campus workers) | 7–10 |
| B | Development / advancement / donor-relations staff at orgs that fundraise from individual donors | 4–7 |
| C | Board members and major donors at qualifying orgs — influencers who can champion DonorSend internally | 4–6 |

**Market scope: ANY nonprofit that fundraises from individual donors** —
Christian, other-faith, or secular. Every org gets `faith_orientation`
tagged (`christian` / `other_faith` / `secular`). An org already on an
enterprise donor CRM is a *competitive-displacement target*, not a reject —
record the incumbent in `crm_incumbent`.

**Do-not-pursue flag (org-level, mission-based):** an organization whose
public mission includes LGBT/transgender advocacy or programming is still
cataloged in `hunt_targets`, with `do_not_pursue = true` and
`do_not_pursue_reason = 'lgbt_advocacy'` — DonorSend does not pursue these
accounts, and roster budget is never spent on them. This classification is
based ONLY on the organization's own published mission/programs. Agents
never record, infer, or flag any individual's sexual orientation or gender
identity — person records carry no such data, period.

## Reason codes (kill test)

Codes observed in real review decisions (backfilled from the 42 rejects)
plus the plan's originals. Retired 2026-08-29: `secular_org` (secular
nonprofits are in scope), `donor_not_fundraiser` (board/donors are now
Tier C), `enterprise_saas` (now `crm_incumbent` intel on the target).

| Code | Rule |
|---|---|
| `church_salaried` | Staff of a single local congregation, salary-funded |
| `school_salaried` | K-12 / college / seminary staff and school networks |
| `denomination` | Denominational bodies and their program offices |
| `conference_training` | Conferences, training orgs, speakers |
| `business_vendor` | Publishers, curriculum vendors, job boards |
| `salaried_leader` | Celebrity pastors/executives; salaried, not support-raised |
| `grant_funded` | Grant/government-funded orgs with no individual-donor fundraising |
| `no_individual_donors` | Org raises nothing from individual donors (endowment-only, fee-for-service) |
| `too_institutional` | Too large/institutional to be a DonorSend user |
| `defunct` | Dead domain, dissolved org, retired/deceased person |
| `platform_not_person` | Roster/aggregator page mistaken for a person |
| `already_in_crm` | Skip-list match |

Exceptions that OVERRIDE org labels (the individual's funding model decides):
support-raised church **planters** and support-raised **campus ministry staff
at schools** are Tier A even though "church"/"school" appears in the org name.

## Wave protocol (short form)

1. **Prep** — run `sql/wave_prep.sql` sections via `execute_sql`; feed results to
   `../scout-import/skip_list_generator.py`; write assignment files.
2. **Fan-out** — launch agents (batches of 10–15) with the matching prompt
   template; each writes one JSON conforming to `schemas/wave_output.schema.json`.
3. **Ingest** — `python3 ../scout-import/scout_import.py ingest-wave hunts/<wave>/out
   --min-fit 4 --out hunts/<wave>/sql` then execute the emitted SQL **directly**
   via `execute_sql` (orchestrator only — never delegate imports to agents).
   `--min-fit 4` matters: Tier B/C records live in the 4–6 band and the
   default of 6 would drop them.
4. **Report** — people added, orgs rostered, headcounts, FP rate, tokens/agent.

## Standing cost rules

- Hunters run on **Haiku 4.5**; Sonnet 5 only for roster escalations;
  never Opus/Fable.
- Agents never read files > 50KB and never execute SQL.
- Every visited URL and issued query is reported in `coverage` — negative
  outcomes included.

## Search budget (learned in wave w2026-08-29b)

- In the remote (cloud) environment, **WebFetch is egress-blocked** for
  arbitrary domains: hunters must use **WebSearch only** and mine names/roles
  from result snippets. Say this explicitly in every hunter prompt.
- WebSearch has a **hard session-wide cap of ~200 calls** shared by the
  orchestrator and all subagents. A thorough roster agent uses 15–30 searches,
  so plan **≤ 8 search-heavy agents per session**; agents launched after the
  cap return zero results and burn tokens for nothing.
- To scale beyond one session's budget, fan out to **sibling cloud sessions**
  (`create_session`) — each gets a fresh cap. Siblings commit their wave JSON
  to a git branch; the orchestrator pulls and ingests centrally.
- If an agent returns zero people with an "exhausted" verdict, check whether
  it was budget-starved before recording the org as exhausted — budget-blocked
  orgs go back to `unrostered`.

## Wave log

- **pilot-2026-08-29** — 5 agents; 53 people, 67 orgs, 134 coverage rows,
  13 negatives; verifier FP rate 0.0% (8/8 verified).
- **w2026-08-29b** — 16 roster agents (8 starved by the search cap);
  240 unique people found, 177 net-new imported; 213 coverage rows.
  Headcounts: Ethnos360 40, Young Life 36, WGM 30, YFC 24, MAF 20,
  Christar 18, Cru 14, Wycliffe 12, Serge 8, Navigators 5. 13 orgs reset to
  `unrostered` for the next wave. Raw outputs in `waves/`.
