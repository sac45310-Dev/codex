# Wave w2026-09-11s — unprobed international sending agencies

**Dispatched:** 4 agents (s-rb-a, s-rb-b, s-interact, s-avant), 18 searches each = 72.
**Loaded:** 128 people · 72 coverage rows · 5 new negatives · 1 new hunt_target (InterAct 842) · 3 targets updated.
**Yield:** 128 / 72 = **1.8 new people per query**, comfortably above the 1.3–1.4 retirement line.

| agency | loaded | fit_score | note |
|---|---|---|---|
| Reach Beyond | 82 | 7 | retirement status unverified — see below |
| InterAct Ministries | 45 | 9 | clean |
| Avant Ministries | 1 | 9 | already worked; see below |

## Method: verify-then-dispatch, applied properly for once

Eight agencies were probed by the orchestrator *before* any agent was spawned.
Three had confirmed per-person surfaces and got agents. Five did not and were
written to `hunt_negatives` rather than handed to an agent to rediscover:
**JAARS** (`?fund-code=` query string), **e3 Partners** (`?fundraiser=`),
**Global Frontier Missions** (no per-person pages), **Pioneer Bible
Translators** (project designation only), **WorldVenture** (portal behind
registration). Christar and Team Expansion were also probed and turned out to
have been rejected already in wave n — see the first process failure below.

Team Expansion produced a **protection precedent** worth more than a roster
would have been: the agency states on its own giving page that *"many workers
are serving in sensitive locations and appear using a codename."* That is an
agency-wide warning. It means a Team Expansion name found on any other surface
is not safe either, and it is now a rule in the shared template.

## Reach Beyond — a real seam with a real defect

The pattern is clean: `reachbeyond.org/missionaries/read/<first>-and-<first>-<surname>`,
trailing `-1`/`-3` being CMS collision suffixes rather than part of the name.
Couples split well. Engineering, broadcast and home-office staff are Tier A
like everyone else — it is a radio agency (formerly HCJB), and the
support-function rule applies.

**But retired and active missionaries share one namespace.** `/missionaries/retired`
is not a separate area, it is an *index pointing back into* `/missionaries/read/`.
A "retired missionaries" query returns `/read/` URLs directly — including
**Chuck and Anita Howard**, whom an agent had emitted as an active Asia Pacific
couple. The 2024 annual report counts **124 retired missionaries**, so this is
not a rare edge.

Handling:
- **Eight people withheld** on positive evidence: Ron and Barb Cline (Honorary
  Board Members for Life, "global ambassadors", former HCJB president), Ed and
  Sue Giesbrecht ("served more than 40 years", began 1974), Chuck and Anita
  Howard and Larry and Linda Burk (both surfaced by the retired-list query).
- The other 82 are loaded at **fit_score 7 rather than 9**, every one carrying
  `meta.retirement_check_required = true` and a sentence in `fit_reason` saying
  the status is unverified. They are prospects worth having; they are not
  prospects worth cold-contacting without a check.
- I could not verify 82 people by hand and did not pretend to. The flag is the
  honest representation of what is known.

Also withheld: `/read/hannah` and `/read/allen`, first-name-only slugs at an
agency that works North Africa / Middle East. Routed to `needs_review`.

## InterAct Ministries — the clean result of the wave

45 people, all high confidence, all on per-person giving pages, zero citation
problems in the audit. The slug is **surname-first** —
`/allen-dave-becky/` titled "Allen, Dave & Becky" — with two variants (an
`-and-` hyphenation, and Canada-category paths). Surnames repeat at this
agency (two distinct Richardson couples, two distinct Curtis households, Dave
Hill and Dave Henry), so a repeated surname here is not a duplicate.

The agent handled both protections without prompting: it avoided `/retired/`,
and it caught that Dave Hill's late wife Sally is named on his page and did not
emit her.

## Two process failures, both mine

**1. I probed for surfaces but not for prior work.** The Avant agent spent 18
searches and returned 10 people, **9 of which were already in the database** —
Avant had been worked on 2026-09-10. Net yield: one person for a full agent
slice. My pre-dispatch probe asked "does a per-person pattern exist?" and never
asked "do we already hold these people?" This is the WWNTBM error from wave n
repeating, one commit after I wrote the rule against it into `WORKED.md`.
The probe checklist is now both questions, and `WORKED.md` directs briefs at
`hunt_negatives` as well as `scout_candidates`.

**2. The Reach Beyond regional split failed.** I gave two agents adjacent
geographic slices; **38 of s-rb-b's 56 names also appeared in s-rb-a's file.**
The region is in neither the URL nor reliably the title, so a search-based
agent cannot be sliced geographically on that domain — both agents converged on
the same indexed pages. Two slices bought 91 unique people instead of ~129.
Split by *slug alphabet or role* on domains like this, not by geography.

One smaller correction at ingest: four `fit_reason`s inferred nationality from
surnames ("German names suggest Europe/Eurasia service", "Portuguese surname").
That is inference the pipeline forbids and it was stripped before load.

## Recommendation

InterAct is small and close to exhausted — leave it. Reach Beyond is worth one
more pass, but **split by slug alphabet, not region**, and only after someone
resolves the retiree question; if a fetch pass ever becomes possible,
`/missionaries/retired` read once would let all 82 pending records be graded
correctly in a single pass. That single page is now the second most valuable
fetch target in the project after `bbfimissions.com/missionaries?show=all`.
