# Wave w2026-08-30e — report

Date: 2026-08-30. 8 Haiku 4.5 roster agents. First wave on the **re-prioritized
queue** and the **board cap**.

## Results

- **46 net-new people** — **13 Tier B / 33 Tier C**.
- **39 coverage rows**. Running totals: **3,557 people · 1,572 coverage rows ·
  35 orgs rostered · 405 unrostered**.

| Org | Tier B | Tier C | Verdict |
|---|---|---|---|
| Lowcountry Food Bank | 4 | 5 | rostered |
| Second Harvest Middle Tennessee | 2 | 3 | rostered |
| Community Food Bank of Central Alabama | 2 | 7 | exhausted |
| Food Bank of North Alabama | 2 | 3 | exhausted |
| Feeding South Florida | 1 | 5 | rostered |
| Mississippi Food Network | 1 | 5 | rostered |
| International Medical Relief | 1 | 1 | exhausted |
| Medical Missions Foundation | 0 | 5 | rostered |

## Did the two changes work? Yes, both.

**Board cap held** — every org returned 5 or fewer board records, against 10-14
in the previous wave.

**Tier B share went from 11% to 28% of the wave** (corpus-wide now 23%). That is
the metric that matters: 13 development officers with named fundraising
portfolios are worth more than the 40 trustees the old prompt would have
returned. Lowcountry Food Bank alone produced a CDO, a major-gifts director and
two donor-services staff — and disclosed Blackbaud Raiser's Edge NXT as its CRM,
which is displacement intel.

## Re-prioritization, and what the old formula got wrong

The queue was re-scored against 44 worked orgs:

- **org_type is the real predictor.** Mean people found: parachurch 15.8 ·
  nonprofit 12.5 · agency 11.7 · **ministry 3.1**. Individual YWAM bases drive
  that last number and are now penalised (4 → down from 40+), though not
  excluded: a base with a public staff-profile page still works.
- **`headcount_est` was dropped entirely.** It was not predictive — Mercy Ships
  (est. 1,600) yielded 13, Ethnos360 (no estimate) yielded 40 — and it was
  steering the queue toward large unreachable targets. Agent-guessed org size
  measures the organization, not what it publishes.

## Data quality is now enforced in code, not prompts

Agents drifted on three things again: integer tiers (`2`/`3`), person names with
the org glued on ("Food Bank of North Alabama — Bobby Bozeman"), and **30 scores
outside their tier band in one wave**. Rather than patch by hand a fourth time,
`scout_import.normalize_person()` now coerces all of it at ingest and reports
what it changed in the wave manifest. Verified against synthetic records for
each defect — including that a legitimate personal-evidence Tier A is left
untouched.

One record needed judgment, not code: Mississippi Food Network's development
director was cited with a **different person's LinkedIn URL**. The name is
corroborated elsewhere, so the record was kept and the bad citation dropped
rather than importing a mismatched source.

## Outstanding

- 405 orgs unrostered. The re-scored queue now surfaces regional food banks and
  medical-mission nonprofits ahead of YWAM bases.
- Second Harvest Middle TN has two people listed as Board Chair (Peters current,
  Youssef from the FY23 audit) — kept both, Youssef flagged as likely
  predecessor.
