# DonorSend Hunter Agent — System Design & Operating Plan

**Version:** 1.0 · 2026-08-29
**Goal:** A scalable, repeatable agent system that scours the public internet for potential DonorSend users — individuals connected to fundraising organizations (including very small ones) — so DonorSend can approach each **organization** with headcounts and differentiated member details. Individuals are never contacted directly.

---

## 1. Where we are today (audit summary)

| Asset | State |
|---|---|
| `sales.scout_candidates` | 3,001 rows: 1,604 pending · 725 approved · 630 skipped · 42 rejected |
| `sales.leads` | 81 promoted leads |
| `tools/scout-import/scout_import.py` | Working: collect → normalize → dedupe → idempotent SQL (NOT EXISTS guards) |
| `tools/scout-import/skip_list_generator.py` | Working: org-name + normalized-URL skip lists → prompt snippets |
| July campaign | 50 niche agents → 291 unique prospects (≈6 people/agent), 59% fit 8+ |

**Gaps this plan closes:**

1. **No coverage memory.** Skip lists only track *people found*. Nothing records *ground already searched* — a URL that yielded nothing gets re-crawled by the next wave. This is the "skip any URL or search already done" requirement.
2. **No org registry.** People are found individually; there is no table of target organizations with roster status and headcount — yet the sales pitch is org-level headcounts.
3. **No machine-usable negative list.** 42 rejects and 630 skips exist as statuses, not as *reason-coded rules* agents can learn from. Churches/schools keep reappearing.
4. **fit_score is on two scales.** ~1,580 rows use 1–10, ~78 rows use 0–100, 1,341 are NULL. Must be normalized before fit-based queries mean anything.
5. **Cost leaks.** The measured audit of the last import session: ~$6–8 API-equivalent spent, 4 of 6 agents returned zero rows, and most spend was agents re-reading 200KB+ files and executing SQL that a single direct `execute_sql` call does for free. Rule going forward: **agents search and judge; the orchestrator imports.**

---

## 2. ICP definition — three tiers, one kill test

> **Revised 2026-08-29:** market scope widened to ANY nonprofit that
> fundraises from individual donors (Christian, other-faith, or secular —
> tagged via `faith_orientation`); board members/major donors became
> Tier C influencers; incumbent-CRM orgs became competitive-displacement
> targets (`crm_incumbent`). The `do_not_pursue` flag on `hunt_targets`
> is set only by manual review on the DonorSend side — agents never
> classify orgs for it, and never record or infer any person's demographic
> or identity attributes.

### Tier A — Support-raised individuals (high fit, score band 7–10)
A person who must **personally raise their own funding**: missionaries, Cru/Young Life/YWAM/Navigators staff, church planters on deputation, agency field workers, support-raised chaplains and campus workers.

**Positive signals (any one qualifies, two or more = high confidence):**
- Personal giving/deputation page (`give.cru.org/...`, `bimi.org/pages/missionary/...`, agency donate slug with their name)
- Prayer-letter archive, "partner with us," "support our ministry," "join our support team" language
- Listed in an agency's missionary directory
- Bio says "raises personal support" / "deputation" / "faith-funded"

### Tier B — Development staff at qualifying orgs (medium fit, score band 4–7)
Advancement/development/donor-relations/stewardship staff at an organization that fundraises from individual donors. They don't raise personal support, but they *operate* fundraising and are the software's buyer-adjacent users.

### Tier C — Board members & major donors (score band 4–6)
They don't fundraise, but they hold the power to champion DonorSend inside the org. Collected with their board role in `meta.role`.

### The kill test (false-positive filter)
**The individual's funding model decides — not the org's label.**

Hard rejects (record in negatives with reason code, never import):
| Reason code | Rule |
|---|---|
| `church_salaried` | Pastor/worship/admin staff of a single local congregation, salary-funded. (Exception: a *church-planting network's* planters on support → Tier A.) |
| `school_salaried` | K-12 / college / seminary faculty & staff. (Exception: support-raised campus ministry staff *at* a school → Tier A.) |
| `no_individual_donors` | Org raises nothing from individual donors (purely grant/government-funded, endowment-only, fee-for-service) |
| `defunct` | Dead domain, org dissolved, person retired/deceased |
| `platform_not_person` | Roster/aggregator pages mistaken for one person |
| `already_in_crm` | Matched skip list |

Retired codes (2026-08-29): `secular_org` — secular nonprofits are in scope, tagged `faith_orientation='secular'`; `donor_not_fundraiser` — board/donors are now Tier C; `enterprise_saas` — the incumbent CRM is recorded in `hunt_targets.crm_incumbent` as displacement intel.

**Gray zone → `needs_review`, never a guess.** An agent that can't determine funding model marks the record `needs_review` with its evidence; a cheap verifier pass (or human) adjudicates. This is what keeps false positives out without silently discarding real prospects.

### Fit score — single canonical scale
Keep **1–10** (existing tooling already filters `--min-fit`). Anchors:
- **10** — Tier A, personal giving page found, active this year
- **8–9** — Tier A, two+ signals, active
- **7** — Tier A, one signal, or Tier A at an unverified small org
- **5–6** — Tier B at a qualifying org, role confirmed
- **4** — Tier B, role inferred
- **≤3** — fails kill test → goes to negatives, not scout_candidates

**Migration (Phase 0):** rows with `fit_score > 10` → `round(fit_score / 10)`; NULLs left NULL but excluded from fit-filtered exports.

---

## 3. Data foundation — three new tables

All in the `sales` schema, created via `apply_migration`.

### 3.1 `sales.hunt_targets` — the organization registry
The backbone of org-first rostering and the headcount pitch.

```sql
CREATE TABLE sales.hunt_targets (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  org_name      text NOT NULL,
  website       text,                -- normalized (no scheme/www/trailing slash)
  org_type      text,                -- agency | network | parachurch | mission_board | ...
  size_estimate text,                -- micro (<10) | small (10-50) | mid (50-250) | large (250+)
  tier_profile  text,                -- 'A' (support-raised staff), 'B' (dev staff), 'AB'
  priority      smallint DEFAULT 5,  -- 1 = roster first
  roster_status text NOT NULL DEFAULT 'unrostered',
                -- unrostered | in_progress | rostered | exhausted | rejected
  headcount_found   int DEFAULT 0,   -- people imported, maintained post-wave
  headcount_est     int,             -- org's claimed size when discoverable
  discovered_by     text,            -- wave/agent that first surfaced it
  last_rostered_at  timestamptz,
  reject_reason     text,            -- kill-test reason code when roster_status='rejected'
  notes         text,
  created_at    timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX hunt_targets_org_site_idx
  ON sales.hunt_targets (lower(trim(org_name)), coalesce(lower(trim(website)),''));
```

**Seeded from:** distinct orgs already implied by scout_candidates summaries + the 15 named majors (Young Life, YFC, Wycliffe, MAF, WGM, Serge, Ethnos360, Cru, Navigators, Christar, Pioneers, SIM, OMS, Reach Beyond, Seed Company) + agency directories (Missio Nexus members, ECFA directory, mission-board lists).

### 3.2 `sales.hunt_coverage` — ground already searched
The direct answer to "skip any URL or search that has already been done." **Negative results are recorded too** — that's the whole point.

```sql
CREATE TABLE sales.hunt_coverage (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind         text NOT NULL,         -- 'url' | 'query'
  value        text NOT NULL,         -- normalized URL, or normalized query text
  domain       text,                  -- for kind='url', the hostname
  outcome      text NOT NULL,         -- found_people | no_people | dead | paywalled | offtopic
  people_found int DEFAULT 0,
  target_id    bigint REFERENCES sales.hunt_targets(id),
  wave_id      text,
  visited_at   timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX hunt_coverage_kind_value_idx
  ON sales.hunt_coverage (kind, lower(value));
```

Normalization matches `norm_site()` in `skip_list_generator.py` (scheme/`www.`/trailing-slash stripped, lowercased). Queries are lowercased, whitespace-collapsed.

**How it's used:** before each wave the orchestrator exports (a) domains with `outcome IN ('no_people','dead','offtopic')` visited < 90 days ago — injected as "do not crawl" lists, (b) prior queries for the wave's niches — the orchestrator drops duplicate assignments *before* dispatch, which is cheaper than telling agents mid-flight.

### 3.3 `sales.hunt_negatives` — reason-coded rejects
```sql
CREATE TABLE sales.hunt_negatives (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_kind text NOT NULL,          -- 'org' | 'person'
  name        text NOT NULL,
  website     text,
  reason_code text NOT NULL,          -- codes from the kill-test table
  detail      text,
  source      text,                   -- 'human_review' | 'agent' | 'backfill'
  created_at  timestamptz DEFAULT now()
);
```

**Backfill (Phase 0):** classify the 42 `rejected` + a sample of the 630 `skipped` scout rows into reason codes (one Sonnet pass over exported rows — this is the training data for the rubric). Negatives feed both the skip snippet and rubric refinements.

---

## 4. Agent architecture

Three agent roles, one orchestrator, all inside Claude Code on the Max 20x plan.

```
┌─────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR (main session, Sonnet 5)                       │
│  refresh skips/coverage → build assignments → fan out       │
│  → collect JSON → scout_import.py → DIRECT execute_sql      │
│  → update coverage/targets → wave report                    │
└──────┬──────────────────┬──────────────────┬────────────────┘
       ▼                  ▼                  ▼
 PROSPECTOR ×N      ROSTER AGENT ×M     VERIFIER ×1–2
 (Haiku 4.5)        (Haiku 4.5 default; (Haiku 4.5)
 niche sweeps →     Sonnet 5 for        samples 10% of
 new orgs + people  ambiguous orgs)     records + all
                    one org each →      needs_review →
                    exhaustive roster   confirm/reject
```

### 4.1 Prospector (discovery) — Haiku 4.5
- **Input:** one niche brief (e.g., "deaf ministry missions," "medical missions Sub-Saharan Africa," "bi-vocational church planting networks"), skip snippet, do-not-crawl domains, output schema.
- **Job:** web search + fetch to surface **organizations** (including micro-orgs: an agency of 4 people counts) and any people encountered incidentally. Orgs are the primary product; they feed `hunt_targets`.
- **Budget:** ≤ 20 searches, ≤ 25 page fetches, ≤ 25 min. Stop early when yield/search drops.

### 4.2 Roster agent (exhaustion) — Haiku default, Sonnet for judgment calls
- **Input:** exactly **one** org from `hunt_targets` (`roster_status='unrostered'`, priority order), with everything already known about it, skip lists, and the tier rubric.
- **Job:** find *every* affiliated person: staff/team pages, agency missionary directories, giving-portal slug patterns (e.g., `give.org/firstname-lastname`), prayer-letter blogrolls, newsletter archives, conference speaker lists, state nonprofit filings for tiny orgs.
- **Escalation rule:** orgs whose site structure defeated Haiku (JS-heavy, roster behind search forms) get retried once on Sonnet 5 before being marked `exhausted`. This is the fix for the earlier "Sonnet/Opus had issues" experience — Sonnet is used *surgically* where Haiku fails, not as the default (July data showed Haiku out-produced Sonnet on straightforward hunts at ~⅕ the cost).

### 4.3 Verifier — Haiku 4.5
- Samples ~10% of each wave's records + 100% of `needs_review`: does the URL resolve, is the person actually on the page, was the tier rule applied correctly?
- Produces the wave's **false-positive rate** — the metric that gates rubric changes.

### 4.4 Mandatory output contract (every agent)
JSON file per agent (the format `scout_import.py` already accepts, extended):

```json
{
  "wave_id": "w2026-09-01a",
  "agent": "roster:ethnos360-aviation",
  "people": [
    {
      "org_name": "Jane Doe",
      "org_type": "missionary",
      "website": "blogs.ethnos360.org/jane-doe",
      "city": "", "state": "",
      "summary": "Ethnos360 Aviation — maintenance specialist, Papua New Guinea",
      "fit_score": 8,
      "fit_reason": "Tier A: personal Ethnos360 giving page + active 2026 prayer letters",
      "source_query": "hunter:w2026-09-01a:ethnos360-aviation",
      "meta": { "tier": "A", "role": "aviation maintenance", "target_org": "Ethnos360 Aviation",
                "evidence_url": "ethnos360.org/missionaries/jane-doe", "confidence": "high" }
    }
  ],
  "orgs_discovered": [
    { "org_name": "...", "website": "...", "org_type": "...", "size_estimate": "micro",
      "tier_profile": "A", "evidence": "..." }
  ],
  "coverage": [
    { "kind": "url", "value": "ethnos360.org/missionaries", "outcome": "found_people", "people_found": 14 },
    { "kind": "url", "value": "example.org/staff", "outcome": "no_people" },
    { "kind": "query", "value": "ethnos360 aviation missionary support", "outcome": "found_people" }
  ],
  "needs_review": [ { "...person...": "with evidence and the open question" } ],
  "negatives": [ { "entity_kind": "org", "name": "First Baptist X", "reason_code": "church_salaried" } ]
}
```

The `coverage` block — including **empty-handed URLs** — is non-negotiable; it's what makes wave N+1 cheaper than wave N.

### 4.5 Rules baked into every agent prompt
- Public web only; no login-walled scraping (LinkedIn pages surfaced by search are recordable as URLs, not crawled behind auth).
- Never fabricate emails/roles — blank beats guessed.
- A URL listing 3+ people is a roster page, not a person (existing scout_import convention).
- Minimum viable record: **name + org + role-or-location + source URL** (the user's selected bar). Email/LinkedIn only when free.
- Hit your budget caps and stop; a truncated honest result beats a padded one.

---

## 5. The wave protocol (repeatable runbook)

**Phase A — Prep (orchestrator, ~5 min, near-zero cost)**
1. `export_existing.sql` → `skip_list_generator.py` → fresh skip snippet.
2. Export coverage: recent no-yield domains + prior queries; export unrostered targets by priority.
3. Build N assignment files (`hunts/<wave>/assignments/`), dropping any assignment whose queries/domains are already covered.

**Phase B — Fan-out (parallel background agents)**
4. Launch agents in batches of 10–15 (staying well inside session task limits), each writing `hunts/<wave>/out/<agent>.json`. Typical wave: 10 prospectors + 25 roster agents + verification at the end.

**Phase C — Ingest (orchestrator, direct — never via agents)**
5. `scout_import.py report` → eyeball stats → `collect --min-fit 6` → execute each batch via **direct `execute_sql`** (idempotent, NOT EXISTS-guarded).
6. Insert `coverage` rows, upsert `orgs_discovered` into `hunt_targets`, insert `negatives`, update `roster_status` + `headcount_found`.
7. Verifier pass on sample + `needs_review` queue.

**Phase D — Report**
8. Wave report: people added, orgs rostered, headcount per org (the sales artifact!), FP rate, tokens per agent (from task notifications), coverage growth. Rubric adjustments proposed only when FP rate > 10%.

**The org pitch query** (what sales actually uses):
```sql
SELECT t.org_name, t.website, t.headcount_found,
       count(*) FILTER (WHERE (s.meta->>'tier')='A') AS support_raised,
       count(*) FILTER (WHERE (s.meta->>'tier')='B') AS dev_staff
FROM sales.hunt_targets t
JOIN sales.scout_candidates s ON s.meta->>'target_org' = t.org_name
WHERE t.roster_status IN ('rostered','exhausted')
GROUP BY 1,2,3 ORDER BY t.headcount_found DESC;
```

---

## 6. Cost model — Max 20x plan

Runtime decision: **Claude Code on Max 20x**, so cost is a share of the weekly usage cap, not dollars. API-equivalent dollars are still quoted as the universal ruler (they're what the plan's usage meter is weighted by internally).

### Measured anchors (from this session's audit — real `usage` data)
- Background Haiku agent (light fetching): **110–140K subagent tokens**
- Session cache hit rate 96.7%; cache reads at 0.1× dominate → marginal cost per agent is small
- Wasted-spend patterns to avoid (measured): agents re-reading 200KB files each turn; agents executing SQL; agents that "prepare" instead of act — these tripled the last session's cost for zero yield

### Per-unit estimates (API-equivalent, search-heavy profiles)
| Unit | Tokens (est.) | API-equiv |
|---|---|---|
| Prospector (Haiku, 20 searches/25 fetches) | 300K–800K, mostly cache reads | **$0.20–0.60** |
| Roster agent (Haiku) | 300K–800K | **$0.20–0.60** |
| Roster agent (Sonnet escalation) | 300K–800K | **$0.80–2.50** |
| Verifier (Haiku, sampling) | 150–300K | **$0.15–0.30** |
| Orchestrator overhead per wave (Sonnet) | — | **$2–4** |

**Standard 40-agent wave** (10 prospectors + 25 Haiku rosters + 3 Sonnet escalations + 2 verifiers + orchestration): **≈ $15–35 API-equivalent**, expected yield 300–600 qualified people + 30–80 newly registered orgs → **≈ $0.04–0.10 per qualified person**, falling each wave as coverage compounds.

### As % of the weekly Max 20x cap
Anthropic doesn't publish the cap in tokens, so the honest method is **one calibration pilot**:

1. Note usage % (claude.ai → Settings → Usage) before and after a **5-agent pilot wave**.
2. `wave_cost_% ≈ (after − before) × N/5` for an N-agent wave.

Rough prior: the July 50-agent campaign completed in a day on this plan without exhausting the cap, and Haiku is the cheapest-weighted model — expect a 40-agent Haiku-heavy wave to land in the **low single digits to ~10% of the weekly cap**, i.e., 3–6 substantial waves/week alongside normal use. Two standing rules protect the cap:
- **Never hunt on Opus/Fable** (≈5–10× Sonnet weighting). Fable = planning sessions like this one only.
- **Orchestrator on Sonnet, hunters on Haiku**, Sonnet only for escalations.

### If scale ever exceeds the cap
The assignment/output file contract is runtime-agnostic. The same JSON briefs can be fed to an API runner (Haiku 4.5 batch-adjacent pricing, web search at $10/1k searches) with zero pipeline changes — a 40-agent wave would run ≈ $25–50 real dollars. Decision deferred until the cap is actually the bottleneck.

---

## 7. Scale-out path

1. **Now (single session):** waves of 30–50 background agents — proven in July.
2. **Parallel sessions:** orchestrator spawns sibling CCR sessions (`create_session`), each owning one wave slice; coverage tables in Supabase are the shared memory, so sessions can't duplicate ground.
3. **Scheduled autonomy:** a weekly Routine fires a fresh session that runs the whole wave protocol unattended and emails the wave report. Prerequisite: two clean supervised waves with FP < 10%.

---

## 8. Metrics & quality gates

| Metric | Target | Source |
|---|---|---|
| False-positive rate (verifier) | < 10% | per wave |
| People per agent | > 8 (rosters), > 3 (prospectors) | wave report |
| Coverage reuse | 0 re-crawls of covered URLs | hunt_coverage joins |
| Cost per qualified person | < $0.10 API-equiv, trending down | task-notification tokens |
| Orgs with headcount ≥ 5 | growing weekly | pitch query |
| needs_review backlog | cleared each wave | verifier |

Human feedback loop — three channels, all driven by your approve/reject/skip actions in the CRM:

1. **Rejections → kill rules.** Rejected rows are reason-coded into `hunt_negatives`; recurring codes tighten the prompt rubric (this created five kill rules in Phase 0 alone).
2. **Approvals → hunting grounds.** Approved org-shaped rows auto-seed `hunt_targets` for rostering, and `wave_prep.sql` §6b computes approval-rate by hunting ground so the next wave's assignments over-weight the niches you actually approve and starve the ones you reject.
3. **Reject-reason trends** (`wave_prep.sql` §6c): a reason code that keeps growing means agents are still bringing that pattern in — the signal to tighten that prompt rule before the next wave.

---

## 9. Implementation phases

**Phase 0 — Foundation (one session, ~2–3 hrs, negligible usage)**
- [ ] Migration: `hunt_targets`, `hunt_coverage`, `hunt_negatives`
- [ ] fit_score normalization (0–100 rows → 1–10)
- [ ] Backfill: seed `hunt_targets` from existing data + 15 majors + directories; classify 42 rejects (+ skipped sample) into `hunt_negatives`; backfill `hunt_coverage` from existing `source_query` values
- [ ] Write the three agent prompt templates + assignment/output JSON schemas into `tools/hunter/`
- [ ] Extend `scout_import.py` with an `ingest-wave` subcommand (reads the extended output JSON, emits candidate SQL **and** coverage/targets/negatives SQL)

**Phase 1 — Calibration pilot (5 agents)**
- [ ] 2 prospectors + 2 rosters + 1 verifier on known ground
- [ ] Record usage % before/after → real cost-per-wave numbers
- [ ] Measure FP rate; tune rubric wording once

**Phase 2 — Production waves (repeat weekly)**
- [ ] 30–50 agents/wave per the protocol; rubric frozen unless FP > 10%

**Phase 3 — Scale & autonomy**
- [ ] Parallel sessions when one wave/session isn't enough
- [ ] Weekly scheduled Routine + emailed wave report after two clean waves

---

## Appendix A — Prospector prompt template (abridged)

> You are a DonorSend prospector. Niche: **{niche}**. Find ORGANIZATIONS (any size — a 4-person agency counts) whose people fit the ICP, plus any individuals you encounter.
> **ICP:** Tier A = individuals who personally raise their own support (missionaries, deputized staff, support-raised planters). Tier B = development/advancement staff at orgs that fundraise from individuals.
> **Kill test — do NOT return:** salaried local-church staff, school/college staff, secular grant-funded orgs, board members who only donate, defunct orgs. If funding model is unclear, put the person in `needs_review` with evidence instead of guessing.
> **Already covered — do not search or crawl:** {skip_snippet} {covered_domains}
> **Budget:** ≤20 searches, ≤25 page fetches. Record EVERY url you visit and EVERY query you run in `coverage`, including the ones that yielded nothing.
> **Output:** exactly one JSON file at {out_path} matching the wave schema. Blank fields beat guessed fields.

## Appendix B — Roster prompt template (abridged)

> You are a DonorSend roster agent. Your single target: **{org_name}** ({website}). Known so far: {known_people_count} people. Your job: find EVERY affiliated person we don't have.
> Check: /staff /team /about /missionaries /our-people pages; the org's page on agency directories; giving-portal name slugs; prayer-letter archives and newsletters; speaker lists. For micro-orgs: state filings, Facebook page "about", charity registries.
> Tier + kill test + coverage + output rules as in Appendix A. Do not return people already in the skip list: {skip_snippet}.
> When you stop, set `roster_verdict`: `rostered` (found the people there are to find), `exhausted` (site defeated me — say how), or `rejected:{reason_code}` (org fails the kill test).
