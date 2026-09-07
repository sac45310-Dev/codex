# Wave w2026-09-07a — report

Date: 2026-09-07. Eight Haiku 4.5 agents: five roster, three prospector.
Fetch-blocked, search-only, 18 searches each — 144 searches, all executed.

## Results

- **39 people — 12 Tier A / 10 Tier B / 17 Tier C.**
- **79 net-new orgs**, 144 coverage rows, 20 negatives.
- Corpus: **774 hunter-found people** (211 A / 194 B / 369 C), 534 orgs,
  1,834 coverage rows, 238 negatives.

## Lane 0 paid for itself before an agent ran

123 of 367 unrostered orgs — **a third of the queue** — matched documented
kill-test reject patterns: 93 local churches carrying a `usachurches.org`
*directory listing* as their "website", plus publishers, seminaries and
professional societies. Rejected mechanically at zero search cost.

The protect-list mattered more than the sweep. A blank regex would have
destroyed five support-raising orgs — the Tier A sources we have least of:

| org | matched on |
|---|---|
| Campus Outreach - University of Memphis | `university` |
| ReachGlobal (Evangelical Free Church of America) | `church` |
| World Witness (Board of Foreign Missions of the ARP Church) | `church` |
| Stadia (Church Planting) | `church` |
| Mission Doctors Association | `association` |

ReachGlobal then produced the wave's best result. The filter that nearly
deleted it would have cost 12 Tier A records.

## The Org is a large-org lever, not a universal one

| org | size | The Org page | Tier B |
|---|---|---|---|
| Operation Mobilization | large | yes | 4 |
| Jesus Film Project | large | yes | 5 |
| Cross International | mid | no | 1 |
| Partners International | mid | no | 0 |

Where it exists it is worth ~5× a general roster pass and costs two searches.
Where it doesn't, it costs two searches to find out. Make it a routing rule on
`size_estimate`, not a universal step 0. Partners International went 18-for-0
on Tier B: its staff page exists but does not resolve into search snippets,
which is the real ceiling of a fetch-blocked environment.

## ReachGlobal: the Tier A pattern worth repeating

12 Tier A records, every one citing a distinct `give.efca.org/missionaries/<name>`
page. **A per-person giving URL pattern is the highest-yield Tier A signal we
have**, and it is visible in search snippets without fetching. Any agency with
one deserves a dedicated pass; finding the pattern should be an explicit early
goal of every roster agent at a sending agency.

## Four orchestrator corrections

Raw agent output is committed before these, so each is a reviewable diff.

1. **ReachGlobal's three Tier B → Tier C.** Director of Mobilization,
   Director of Crisis Response, Executive Director of IMA Personnel:
   recruitment, programme and HR. Tier B means donor-facing.
2. **OM's "Latino Diaspora Mobilization Officer" → Tier C**, same rule. The
   agent's stated basis was `mobilization_implies_development` — inference
   from a word, not evidence of a role.
3. **33 of 42 medical orgs: `tier_profile` A → B.** Their notes were org
   descriptions ("Eye care services nonprofit since 1974"), not support-raising
   evidence. `tier_profile` A adds 20 priority points, so unearned A would have
   floated the whole batch to the top of the queue.
4. **23 of 43 negatives discarded, not loaded.** Thirteen were coded
   `already_in_system` for orgs we deliberately *have* — Operation Mobilization,
   Jesus Film Project, Campus Outreach, Mission Doctors Association. The targets
   insert refuses anything present in `hunt_negatives`, so loading those would
   have permanently blocked re-adding our best targets. Others recorded
   uncertainty (`insufficient_evidence`, `too_small`) as if it were a ruling.
   **A skip-list confirmation is not a rejection, and neither is a shrug.**
   The rest were remapped onto canonical reason codes.

## Two pipeline fixes this wave forced

- **Person-shape aliasing.** The first ingest returned `unique_people = 0`.
  Agents emitted `{name, org, role, tier}`; the schema stores the person's name
  in `org_name` with the employer in `meta.target_org` — a `scout_candidates`
  reuse no agent guesses unprompted. The prompt spec was mine and it was wrong.
  `normalize_person()` now maps the flat shape instead of dropping it, so a
  prompt/schema drift can never again silently discard a whole wave.
- **Website-based batch dedup**, with the same `>=3` guard as `dedupe()`: a
  domain on 3+ name-distinct orgs is a national site, not an identity. The
  medical batch shipped `Medical Missions for Children` and
  `Medical Missions for Children - MMFC` on one domain (caught, one row landed);
  the campus batch shipped ten Campus Outreach chapters that the guard protects.

## Correction to earlier reports

Previous waves reported a cumulative **"3,736 people"**. That figure counted
every `scout_candidates` row. The table holds three kinds: 774 hunter-found
people (tiered), ~1,125 person-shaped rows from pre-hunter scout work, and
~1,876 **organization** rows. Per-wave deltas and tier splits were computed on
tiered rows and stand; the cumulative headline was inflated and is corrected
here. The honest number for what this system has produced is **774 people**.

## Outstanding

- 318 orgs unrostered. The queue is now genuinely agency-rich: IMB, Pioneers,
  SIM, Wycliffe, Frontiers, Ethnos360, Cru, Young Life, InterVarsity, FCA.
- **`org_type` on backfilled rows is unreliable** — Operation Mobilization and
  Cross International were typed `ministry` by a backfill default, so scoring
  `ministry` at 2 buried the very targets this wave proved best. Lane 1 was
  dispatched on evidence rather than rank because of it. Re-typing the
  backfilled rows should come before the next priority-ranked wave.
- Nine Campus Outreach chapters and several FOCUS/Cru city teams carry no
  website; they need a domain before they can be rostered.
