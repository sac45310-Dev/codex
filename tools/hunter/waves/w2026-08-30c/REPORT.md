# Wave w2026-08-30c — report

Date: 2026-08-30. 8 Haiku 4.5 roster agents, search-only. Second wave on the
priority queue; first wave carrying the "tier down when ambiguous" rule.

## Results

- **43 net-new people** imported (`source_query LIKE 'hunter:w2026-08-30c%'`).
- **47 coverage rows**; 24 negatives; 10 records parked in needs_review.
- Running totals: **3,448 people · 1,486 coverage rows · 24 orgs rostered**.
- Hot queue (priority >= 70) down from 28 to **20**.

| Org | People | Verdict |
|---|---|---|
| Medical Missionaries | 16 | rostered |
| YWAM Ships Kona | 4 | rostered |
| YWAM Orlando | 5 | exhausted |
| Flying Doctors of America | 5 | rostered |
| Volunteers in Medical Missions | 5 | rostered |
| YWAM Montana | 3 | rostered |
| YWAM Tyler | 3 | exhausted |
| World Medical Mission | 3 | exhausted (program of Samaritan's Purse) |

## Rule check: 1 violation in 45 records

Automated check for bad names, hedged Tier A, and execs-as-Tier-A found a
single hit — and it exposed a real gap rather than agent sloppiness.

**YWAM Montana** returned three Tier A records justified by *"YWAM staff raises
own support per organizational model"* — inference from org policy, not
per-person evidence, which the rule as written forbade. But for YWAM the
org-level fact is true and documented: every staffer does raise support.
Tiering these down to C would have destroyed real signal to satisfy a rule that
had simply not anticipated the case.

Resolution: org-wide documented support-raising policy now counts as Tier A
evidence, but must be **marked** — `meta.evidence_basis = "org_policy"`,
confidence capped at medium, score pinned to 7 (bottom of the A band). A
personal giving page still outranks a policy page, and the CRM can now tell
them apart. Prompt updated accordingly.

## Judgment calls worth recording

- **Chloe Kalinke (YWAM Ships Kona)** was returned as Tier A on a $13k GoFundMe,
  but the campaign is for a 3-month DTS course plus outreach — she is a trainee,
  not staff, and the kill test excludes trainees. Held out of the import and
  logged as a negative. Genuinely arguable: she *is* an individual raising
  support from donors, which is the product's core use case. If DonorSend wants
  trainees in scope, that is a deliberate ICP change, not a bug fix.
- **World Medical Mission** is a department of Samaritan's Purse with
  advancement centralized at the parent — same shape as the Global Health
  Outreach/CMDA rejection last wave. Two data points now suggest a pattern:
  program-of-a-larger-org targets score well on size but rarely have their own
  addressable staff. Worth a prospector-level filter.
- **YWAM Orlando and YWAM Tyler** were marked exhausted rather than rostered:
  both agents found 10+ additional staff names but could not verify them, and
  correctly declined to emit unverified records.

## Outstanding

- 20 orgs remain in the hot queue; 421 unrostered overall.
- 10 needs_review records from this wave await a verifier pass.
