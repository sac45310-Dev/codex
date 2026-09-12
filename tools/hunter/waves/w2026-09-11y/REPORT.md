# Wave w2026-09-11y — Encompass World Partners

**4 agents, 72 searches. 8 people loaded. Yield 0.11 per query — the worst of
the session.** The wave should not have been dispatched.

## Why: I made the same mistake twice

Encompass World Partners was **already heavily worked** — roughly 47 records
in the database, nearly all approved. The agents re-found the Fergusons, the
Offutts, the Higbys, the Burgesses, the Mirones, the McCamans, the Yoders,
Junko Saito, Elise Klawitter, Diana Davis, JB Brown, Brian Baughman, the
Klawitters, the Guileses, the Malaraes, the Kerns, the Mensingers and more.

This is the **Avant error from wave s, repeated.** After Avant I wrote that
the pre-dispatch probe must ask two questions — *does a per-person surface
exist* and *do we already hold these people* — and added a section to
`WORKED.md` about it. I then probed the surface, confirmed it beautifully, and
never ran the second query. One `select` against `scout_candidates` would have
killed this wave before it cost four agent slices.

**The probe is not done when the pattern is confirmed. It is done when both
questions are answered.**

## What the wave was nonetheless worth

Two findings justify part of the cost.

### 1. Short-term trip participants are already polluting the approved pool

The brief's new trap — that Encompass runs short-term trip participants on the
same `/person/` surface as career missionaries — turned out to describe
records **already approved in the CRM**:

| person | status found | what the page actually says |
|---|---|---|
| **Charity Reist** | approved, score 9 | *"going to France with Encompass in May and June 2026… missions work has not specifically been on her heart before"* |
| Kya Bolding | approved, score 9 | intern "discerning a long-term role" — but also "her support empowers Kya", so genuinely ambiguous |
| Malachi Saunders | approved, score 7 | "has served on mission with Encompass **twice**" |
| Randy & Susan Clark | approved, score 8 | "plan **annual travel** to Japan to support the team" |

Charity Reist was verified independently by the orchestrator and **returned to
`pending`** — a two-month trip participant is not someone managing a personal
donor base. The other four were **annotated but left approved**, because the
short-term boundary is an ICP decision for the owner, not one to make
unilaterally across records already approved under a blanket rule.

All three agents independently flagged the same people, which is why this is
reported as a finding rather than one agent's opinion.

### 2. The agents caught anonymization, then emitted it anyway

`/person/esn` — "E. & S. N. #3515" — was correctly routed to `needs_review` by
every agent. But the same files **emitted six protected records as people**:
bare `Betsy`, `Holly`, `Jason`, `Roy`, and `Jason C.` / `Christy C.` with
initials-only surnames. Several appear in `needs_review` *and* in `people` in
the same file.

All six were withheld at ingest. This is the third wave where an agent has
both identified a protection case and emitted it — the pattern is that agents
apply the rule when reasoning explicitly about it and forget it when merely
listing results. The ingest guard is what actually enforces it.

One agent also re-emitted Cecil O'Dell after being told explicitly not to.

## Loaded

8 people, all career assignments verified against the short-term trap:
Tom Barlow (Brazil), Denver Murray (Mexico), David & Kathy Manduka (Germany),
Florent & Lori Varak (France), Alfredo & Rita Abreu (Portugal).

## Recommendation

Do not run another Encompass wave. More usefully: **before the next wave of
any kind, run the two-question probe properly**, and consider that the
short-term-participant question probably affects other agencies already in the
database — any agency whose giving surface serves trips and careers from one
path. That audit is cheaper than another wave and is likely worth more.
