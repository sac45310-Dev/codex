# Which model runs which part of the hunter

Written 2026-09-22 after measuring a real wave. The short version: the
hunter's work is mostly mechanical, the mechanical parts were running on the
most expensive model available, and nothing in the repository said otherwise.

## What was measured

Wave w2026-09-22a screened 221 organisations across eight parallel agents.
Every one of them inherited the orchestrating session's model and effort
setting, because the `Agent` tool's `model` parameter was never passed and
no default was configured anywhere.

| | |
| --- | ---: |
| Subagents | 8 |
| Tokens consumed by subagents | 645,339 |
| Tool calls | 271 |
| Model each ran on | the orchestrator's — the most capable tier |
| Effort level | max |

The task each agent performed: run a web search, look at the returned URL
list, and decide whether any path or parameter contains a person's name.
That is pattern recognition over a short list of strings. It does not need
frontier reasoning, and paying frontier prices for 645,000 tokens of it is
the single clearest waste in the pipeline today.

## The rule

**Pass `model` explicitly on every `Agent` call.** Omitting it does not pick
a sensible default; it inherits the orchestrator, which is the most expensive
option in the session. This is the whole bug.

| tier | model | what runs here |
| --- | --- | --- |
| **Mechanical** | `haiku` | URL-shape classification, giving-domain screening, page parsing, email extraction, dedupe checks, name-shape tripwire, coverage bookkeeping. The high-volume majority of all agent calls. |
| **Judgment** | `sonnet` | Grading a candidate against the tier rubric, resolving an ambiguous verdict a mechanical pass flagged, couple-page role assignment, deciding whether a named page is staff or a third-party directory bio. |
| **Design** | `opus` | Rule design, wave briefs, auditing a finished wave, anything that changes how the pipeline itself behaves. Rare, and usually the orchestrator rather than a subagent. |

Effort level follows the same shape. A mechanical agent at `max` effort is
paying for deliberation it has no use for.

## Why not run everything on the cheap tier

Two failure modes in this wave were judgment errors, not mechanical ones, and
both would survive a model downgrade only if the rule is written well enough
to make them mechanical:

- **Pioneers** publishes per-person giving as query parameters rather than
  path segments. The screen missed it because the *rule* said "name in the
  path", not because the model was too weak. Fixing the rule fixes it at
  every tier.
- **PlanterMatch** and **Praxis Labs** have named person pages that belong to
  third-party directory listings, not their own support-raised staff. A model
  that only matches shapes will wrongly promote both. This one genuinely
  needs judgment, so route flagged rows to the judgment tier rather than
  trying to express it as a pattern.

The pattern to aim for: a cheap pass that is deliberately eager and flags
anything ambiguous, feeding a much smaller judgment pass. Cheap-and-eager
plus expensive-and-rare beats one expensive pass over everything.

## Practical notes

- The `Agent` tool takes `model` per call. Set it every time.
- A default subagent model can be configured so that an omission is not
  automatically the most expensive choice. Worth doing.
- Subagents share the orchestrating session's web-search budget. Eight agents
  exhausted a 200-call budget partway through wave w2026-09-22a and 70 of 221
  rows went unscreened as a result. Budget the fan-out against the cap, or
  run fewer agents with more rows each.
- Agents cannot fetch pages from this environment. The egress proxy refuses
  ministry domains, which is an organisation policy decision and not
  something to route around. Search is the only research tool available here,
  and search returns organisation-level addresses, never per-person ones.
  Email extraction therefore cannot run in this environment at all, whatever
  model it uses.
