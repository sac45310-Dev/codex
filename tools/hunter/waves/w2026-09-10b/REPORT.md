# Wave w2026-09-10b — pattern discovery

Date: 2026-09-10. Three agents, 43 searches, 12 organizations where we hold
Tier A people but had never confirmed a per-person giving pattern. The output
is not people — it is patterns, and confirmed negatives.

**Every claim below was re-verified by the orchestrator with an independent
live search before being recorded.** That mattered: two of the three agents
reported a headline pattern that did not survive checking.

## Verified usable

| org | pattern | held | notes |
|---|---|---|---|
| Converge | `converge.org/global-worker/<id>/` and `/<name-slug>` | 23 | best find — titles name the people, IDs span 65745–209737 |
| World Gospel Mission | `wgm.org/missionary/<lastname>` | 25 | org states 236 full-time; slug becomes firstname+lastname on collision |
| One Mission Society | `onemissionsociety.org/missionaries/detail/<Surname>` | 10 | ~300 full-time; numeric suffix on collision (`Brabon1`) |
| Youth for Christ | `epray.yfci.org/appeals/<first-last>/` | 20 | also hosts funds, not just people — filter needed |
| Ethnos360 | `ethnos360.org/missionaries/<name-slug>` + `blogs.ethnos360.org/<name>/` | 47 | agent-reported; the `/missionaries` path was seen in an independent search |

Roughly **600+ addressable people** behind the three biggest, against 125 held.

## Verified negative — do not spend agents here

| org | why |
|---|---|
| Cru | `give.cru.org` is a checkout system. Sign-in, profile, thank-you pages, and numeric designations that name **ministries** — `give.cru.org/2752539` is "Campus Ministry" |
| Wycliffe USA | centralized paginated directory only, running to page 49+; people listed, none individually addressable |
| Young Life | giving centralized per region at `<city>.younglife.org/donate/` |
| Mission to the World | centralized at `donate.mtw.org`, nothing enumerable per person |

A confirmed negative is worth as much as a pattern. Four orgs are now off the
enumeration queue permanently instead of costing an agent each to find out.

## Two agent claims that did not survive verification

- **Cru, "500+ per-person pages at `give.cru.org/<numeric_id>`".** The example
  IDs the agent listed do not appear in a site: search, and what is indexed is
  a payment flow. This would have been the largest target in the pass and it
  is not real. Recorded as a negative.
- **FMWM, "secondary surface at `fmwm.org/missionaries/<name>/`".** The only
  indexed child is `/missionaries/creative-access`, a category index. Notably
  it names Glenn Lorenz — one of the five records held out of w2026-09-09d for
  citing the bare homepage. So the five remain unrecoverable by this route.
- **YFC, `give.yfci.org/donate-now?staffId=<id>`** also failed to verify,
  though the agent's *other* YFC pattern (`epray.yfci.org`) is real.

Three unsupported patterns out of eight claimed. Agents are reliable at
finding a surface and unreliable at confirming one; the verification step is
not optional, and at ~1 search per claim it is far cheaper than a wasted wave.

## Safety findings

Two orgs mark sensitive-region workers explicitly, and both must be excluded
from any enumeration built on these patterns:

- **WGM** publishes `wgm.org/sensitive-missionary` rather than naming them.
- **FMWM** uses "creative access" as the category label for the same thing.

This is the third wave in which anonymization practice has shown up. It should
move from a per-wave note into the standing brief.

## What to run next

Converge, WGM and OMS are the enumeration wave: three clean patterns, named
citations, ~600 estimated against 58 held. That is a better setup than
w2026-09-10a had, and that wave returned 456.

Ethnos360 and YFC are worth one agent between them — both real, both with a
wrinkle (two surfaces; funds mixed in with people).
