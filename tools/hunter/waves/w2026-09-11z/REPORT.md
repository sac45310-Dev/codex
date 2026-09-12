# Wave w2026-09-11z — Africa Inland Mission

**4 agents, 72 searches. 6 people loaded. 0.08 per query.** The worst yield of
the session, and the third redundant wave in a row.

## I ran the holdings check this time and it still failed

After wave y I wrote that the fix was to ask both questions before dispatch:
does a per-person surface exist, and do we already hold these people. **I asked
both.** The holdings query returned zero rows and no negatives, so I dispatched.

The query was keyed on `aim.org`. **AIM's domain is `aimint.org`.** The agency
had already been worked on 2026-09-10 — 64 records on `usgiving.aimint.org`,
the exact surface and pattern this wave "discovered".

The wrong domain broke *both* halves of the checklist at once:

- The first surface probe, `site:aim.org ...`, returned nothing but Wikipedia.
  I read that as "wrong domain" and retried — correctly.
- The holdings probe, `source_url ilike '%aim.org%'`, returned zero. I read
  that as "unworked" — incorrectly, because it was the same bad input.

I caught the error in one place and not the other, because a wrong domain
*looks different* in a search (obvious junk results) than in a database query
(a clean, confident, empty answer). **An empty result from a hand-typed
identifier is not evidence of absence.**

The fix is not "remember to check". It is: **re-run the holdings check against
the domain the probe actually discovered, and against the org name, not the
domain you guessed.** Had I re-queried `usgiving.aimint.org` after the probe
corrected me, the wave would have died there. One line, three wasted waves ago.

## What the wave is actually worth

**The agents were the best-behaved of the entire session**, and that is a
finding about brief design rather than about luck:

| slice | people | protection violations | grading violations |
|---|---|---|---|
| z-east | 53 | 0 | 0 |
| z-central-west | 57 | 0 | 0 |
| z-south-islands | 57 | 0 | 0 |
| z-roles | 60 | 0 | 0 |

Every one of 227 records was graded `medium`, with **zero** exceptions. Every
first-name-only entry (Lea Shabangi, Abigail, Kim, Lisa) went to
`needs_review`. Both labelled retirees — Stephen and Debbie Wolcott, Fred D.
and Jan Beam — were caught by all four agents independently.

Compare wave u, where agents ignored a 149-surname exclusion list, re-emitted
people withheld as retired, and emitted `"Kent"` and `"Kim"` as people. And
wave y, where agents routed one anonymized couple correctly and then emitted
six other protected records.

**The difference is that this brief's rules were unconditional.** "Every record
from this agency is medium. No exceptions." "Any title beginning Retiree goes
to needs_review." No judgment, no thresholds, nothing to weigh. Wave u's rules
were conditional — *apply these exclusions when results repeat*, *grade high
when the slug ties to the name* — and conditional rules are the ones agents
drop under load.

That is worth more than 6 people: **write agency rules as unconditional
statements wherever the agency's structure permits it.**

## The other finding: AIM labels its retirees

`usgiving.aimint.org/missionary/1061450` is titled **"Retiree - Stephen and
Debbie Wolcott"**. No other agency in this project puts the word in the title.
The retiree trap has cost withheld records at Baptist Church Planters, Reach
Beyond, BBFI and Wycliffe, always by inference; here it is simply readable.
Recorded on the target.

## Surface depth

227 raw records collapsed to **66 unique across just 35 distinct URLs** — the
four slices converged almost completely (44–53 overlap between every pair).
The AIM index exposes a shallow set regardless of qualifier, the same
phenomenon that ended Wycliffe in wave u. AIM should be treated as
search-exhausted at roughly 70 held.

## Loaded

6 people: Ellen Admiraal, Jennifer Jacobs, the Mirichs, and two others not
present in the 2026-09-10 pass. Three withheld — Lea Shabangi and Michelle
Gennaro Lapp were flagged by an agent, and "P. Rodney Kraybill" was a spelling
duplicate of Rodney Kraybill.
