# Wave w2026-08-30b — report

Date: 2026-08-30. 4 Haiku 4.5 roster agents, search-only. First wave run with
the hardened prompt rules (commit a11ff41) and the priority-ordered queue.

## Purpose

Two jobs at once: work the top of the newly prioritised roster queue, and test
whether the two prompt fixes actually hold in live output.

## Results

- **40 net-new people** imported (`source_query LIKE 'hunter:w2026-08-30b%'`).
- **31 coverage rows**; 1 org rejected with a reason code.
- Targets drawn from the top of the priority queue (all scored 82–90).

| Org | People | Verdict |
|---|---|---|
| Medical Teams International | 20 | rostered |
| Mercy Ships | 13 | rostered |
| YWAM University of the Nations Kona | 5 | rostered |
| Global Health Outreach (CMDA) | 2 | rejected: too_institutional |

## Did the prompt fixes hold? Yes.

Automated check across all four outputs: **0 rule violations**.

- **Tier discipline.** 30 of 40 records came back Tier C — every CEO, CFO, COO,
  provost and board member landed there rather than in Tier A. Under the old
  prompt these were exactly the records that came back mislabelled Tier A.
- **Named individuals.** No job postings, no single-token names, no role labels
  in any output.
- The only 4 Tier A records are YWAM Kona staff, each carrying a public
  personal fundraising page as evidence — the tier is doing real work now.

One record still needed a hand correction at ingest: the GHO agent tagged
Andy Lamb Tier A while its own `fit_reason` said "no explicit donation page
confirmed". Retiered to C. The rule was stated correctly and the agent even
articulated the doubt — it just resolved the doubt the wrong way, so the
remaining gap is "when unsure, tier DOWN", not the definition itself.

## Judgment worth keeping

Global Health Outreach was correctly rejected as `too_institutional` — it is a
program of CMDA (a membership association), not a standalone donor-funded
organization. That is the kill test working on a target the priority score
ranked highly, which is the right division of labour: score for where to look,
kill test for whether to keep.

## Outstanding

- **28 orgs remain in the hot queue** (priority >= 70), 429 unrostered overall.
- Next batch should continue down the queue: YWAM Montana, YWAM Orlando,
  YWAM Tyler, YWAM Ships Kona, Medical Missionaries, Flying Doctors of America,
  World Medical Mission, Volunteers in Medical Missions.
