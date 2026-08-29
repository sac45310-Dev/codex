# Wave w2026-08-30a — sibling session assignments

Wave ID for all outputs: `w2026-08-30a`. Output schema:
`tools/hunter/schemas/wave_output.schema.json`. Prompt templates:
`tools/hunter/prompts/roster.md`, `prospector.md`, `verifier.md`.

Hard rules for every agent in this wave (learned in w2026-08-29b):

- **WebSearch ONLY.** WebFetch/curl are egress-blocked in remote sessions —
  mine names and roles from search-result snippets. Say this in every
  agent prompt.
- **~200 WebSearch calls per session, total.** Cap each agent at ~25
  searches; launch at most 8 search-heavy agents per session.
- Agents run on **Haiku 4.5**. Never execute SQL; never read files > 50KB.
- Record every query issued (found or not) in the output's `coverage` array.
- Minimum record: name + org + role + source URL. Never flag individuals
  for org-level attributes; org flags (faith orientation, do_not_pursue)
  go on the org only.

## Session A — roster 7 orgs (one roster agent each)

1. Pioneers (pioneers.org)
2. SIM International / SIM USA (sim.org, simusa.org)
3. One Mission Society (onemissionsociety.org)
4. Reach Beyond (reachbeyond.org)
5. Seed Company (seedcompany.com)
6. Christian Health Service Corps (healthservicecorps.org)
7. East-West Ministries International (eastwest.org)

Write outputs to `tools/hunter/waves/w2026-08-30a/roster_<org>.json`.

## Session B — roster 6 orgs + verifier

1. Encompass World Partners (encompassworldpartners.org)
2. Global Gates Network (globalgates.info)
3. Liebenzell Mission USA (liebenzellusa.org)
4. Mesa Global (mesaglobal.co)
5. New International (newinternational.org)
6. WEC International USA (wec-usa.org)

Verifier agent: verify the 12 records in
`tools/hunter/waves/w2026-08-29b/needs_review.json` plus a random sample of
8 from the w2026-08-29b roster JSONs in the same directory. Output to
`tools/hunter/waves/w2026-08-30a/verifier_w2.json` with per-record verdicts
`verified | still_unclear | reject(reason_code)`.

Write roster outputs to `tools/hunter/waves/w2026-08-30a/roster_<org>.json`.

## Session C — 6 prospector niches (one prospector agent each)

1. Secular nonprofit continuation (community foundations, human services)
2. Medical missions organizations
3. Sports ministry organizations
4. YWAM bases (individual US bases, support-raised staff)
5. Veteran / military family nonprofits
6. Food banks — southeast US

Write outputs to `tools/hunter/waves/w2026-08-30a/prospector_<niche>.json`.

## Already-covered queries — NEVER re-issue these

The following queries are already in `sales.hunt_coverage`; issuing them
again wastes budget. (Session A orgs mostly; Session B/C ground is fresh.)

- "east-west ministries" missionaries support plano texas
- "reach beyond" missionary "personal support" giving page
- "serving with east-west ministries" missionaries
- christian health service corps medical missionary
- hcjb global reach beyond missionaries colorado springs
- one mission society - missionary
- pioneers missionary organization unreached people groups
- pioneers.org leadership staff president orlando
- reach beyond medical missionaries ecuador
- seed company staff team translation ministry
- seed company wycliffe bible translation fundraising missionaries
- site:eastwest.org leadership president director
- site:eastwest.org missionary staff team
- site:pioneers.org "serving with pioneers" missionary
- site:pioneers.org missionary support raising give
- site:pioneers.org mobilization development unreached
- site:pioneers.org staff directory team
- site:reachbeyond.org "serve with us" missionary team
- site:reachbeyond.org missionary staff colorado springs
- site:reachbeyond.org president director leadership
- site:sim.org missionary stories staff
- site:simusa.org missionary give donate
- site:simusa.org workers staff
- "sim missionary" niger support raise
- "serving with sim" personal support
- us pioneers missionaries raising personal support with an active blog or email newsletter

## Deliverable

Each session commits its JSON outputs to branch
`claude/hunter-agent-chat-recovery-17shr8` (pull latest first; commit only
files under `tools/hunter/waves/w2026-08-30a/`; pull --rebase before push to
avoid clobbering sibling commits). **Do not run any SQL** — the orchestrator
session ingests centrally.
