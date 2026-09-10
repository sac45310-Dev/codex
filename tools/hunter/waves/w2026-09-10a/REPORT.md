# Wave w2026-09-10a — untouched giving domains

Date: 2026-09-10. Eight enumeration agents, 15 searches each (120 executed),
against domains chosen on one criterion: each shows a per-person giving URL
pattern and **had never had a single `site:` query run against it**. Every
person we already held from them was found incidentally by a hunt aimed
elsewhere.

## Results

**456 people loaded, all Tier A.** The thesis held — untouched ground beat
re-mining worked ground by a wide margin.

| agent | domain | found | loaded | pattern |
|---|---|---|---|---|
| enum-bimi | bimi.org | 132 | 132 | `/pages/missionary/<id>` |
| enum-fbmi | fbmi.org | 72 | 72 | `/prayer-letters/<names>-...` |
| enum-aim | usgiving.aimint.org | 64 | 64 | `/missionary/<id>` |
| enum-modernday | modernday.org | 96 | 96 | `/profile/<name>` |
| enum-wwntbm | wwntbm.com | 60 | 60 | `/connect/missionaries/<name>/` |
| enum-intervarsity | donate.intervarsity.org | 23 | 23 | `/support/<name>` |
| enum-givesendgo | givesendgo.com | 5 | 5 | `/<campaign>` |
| enum-travelingteam | thetravelingteam.org | 12 | 4 | roster page, few per-person |

System totals: **1,221 Tier A approved / 981.3 evidence-weighted**, 115 org
leads, 0 pending.

## Untouched beats re-mined

w2026-09-09d mined six already-worked agencies for 297. This wave mined eight
never-searched domains for 456, at the same search budget. The exclusion tokens
built yesterday barely mattered here — these domains held 6–22 people each, so
there was almost nothing to exclude. What mattered was that **nobody had ever
run a `site:` query against them.**

The selection rule generalises: rank candidate domains by
`people_found > 0 AND queries_spent = 0`. That is now a one-line query against
`v_hunt_domain_status` joined to `hunt_coverage`, and it should be the first
thing checked before any future wave.

## Corrections applied before load

- **BIMI — 128 records lowered from high to medium.** Its giving URLs are
  opaque numeric IDs; the name appears only in the search-result title. Same
  defect GEM produced twice before. The assignment warned against it explicitly
  and the agent did it anyway, which makes this a prompt problem, not an agent
  problem — the rule needs to be in the shared brief, not the per-agent note.
- **The Traveling Team — 8 of 12 dropped.** Names were first-name-plus-initial
  ("Seth F.", "Brit C."), harvested off a roster page that abbreviates surnames.
  Not recoverable without fetching, which is blocked.
- **InterVarsity — 5 numeric-ID records lowered to medium** on the same rule.
- Prose counts disagreed with file counts in **four of eight** agents (BIMI
  143→132, Modern Day 100→96, WWNTBM 61→60, FBMI 66→72). Traveling Team was
  listed here originally as a fifth; that was wrong — its prose count of 12
  matched its file, and the 12→4 drop was the orchestrator dropping fragments
  at ingest, not the agent misreporting.
  The files are authoritative. This is now the single most reliable agent defect
  and the brief should stop asking for a prose count at all.

## One suspicion raised and withdrawn

AIM's output cited `usgiving.aimint.org/missionary/<id>`, but every AIM URL
already in the database is `/category/missionary/<id>`. That looked like
constructed URLs, so the load was stopped and the path checked against live
search: `/missionary/<id>` is the current live shape and `/category/` is the
older one. The agent had found the real path; the database was carrying the
stale one. No fabrication.

Worth recording because it also breaks URL dedup: the same person exists under
two path forms, and `norm_url` treats them as different records. Dedup for AIM
was done on the numeric giving ID instead. Any future platform that renumbers
or re-paths its URLs will need the same treatment.

## InterVarsity: the org is marked a negative, and that looks wrong

`hunt_negatives` has InterVarsity Christian Fellowship as `conference_training`,
recorded 2026-08-30. The promotion therefore excluded it, and its 23 people are
loaded but attached to no lead.

That classification does not survive this wave's evidence: 23 campus staff with
individual giving pages on the organisation's own `donate.intervarsity.org`
subdomain is direct evidence of per-person support raising. `conference_training`
most likely came from an earlier agent meeting an InterVarsity *conference*
(Urbana) rather than the organisation.

**Left as-is pending a human call.** Reversing a recorded team rejection is not
an orchestrator decision, and the cost of leaving it is only that one lead row
is missing — the people are safely in the database either way.
