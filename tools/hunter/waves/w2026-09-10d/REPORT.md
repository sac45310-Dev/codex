# Wave w2026-09-10d — first wave from the shared template

Date: 2026-09-10. Six agents, 90 searches. The first wave whose brief was
rendered from `prompts/enumeration.md` rather than hand-written.

## Results

**365 people loaded**, taking the system to 2,900+ hunter records.

| agent | org | loaded | note |
|---|---|---|---|
| eth-americas-africa + eth-asia-pacific | Ethnos360 | 228 | pattern never enumerated before |
| maf | Mission Aviation Fellowship | 90 | UUID path, name in slug |
| oms-continuation | One Mission Society | 33 | |
| wgm-continuation | World Gospel Mission | 13 | near exhaustion |
| yfc | Youth for Christ | 1 | pattern exhausted |

Ethnos360 enters the top five accounts at 96 (275 Tier A / 252.5 weighted),
and MAF joins them at 96 from a standing start of 13.

## The template's own premise did its job

Every pattern was verified live before dispatch, which is what the template
demands. That killed one target before it cost anything: Encompass World
Partners had been rated usable by the discovery pass, and
`give.encompassworldpartners.org` returned nothing. It was dropped rather than
given an agent.

It also rescued one. MAF's URL is
`give.maf.org/s/fund/<uuid>/<num>-<names>-ministry-support`, which reads as the
opaque-ID case the template warns about. It is not — the name is in the slug.
Without that note in the assignment the agent would have followed the rule
literally and downgraded 90 good records to medium.

## Yield is a function of whether the ground is untouched, again

| target | prior state | yield |
|---|---|---|
| Ethnos360 | pattern confirmed, never mined | **228** |
| MAF | pattern confirmed, never mined | **90** |
| OMS | mined twice already | 33 |
| WGM | mined twice already | 13 |
| YFC | pattern confirmed, tiny index | 1 |

The two continuations were told explicitly not to rotate by country, since two
geographic sweeps had already bought that ground, and to use collision
suffixes, roles, programme names and tenure language instead. They still
returned little. WGM is at 139 of a stated 236 and is reaching the limit of
what search will surface; OMS at 220 of ~300.

## Corrections applied before load

- **14 OMS records were combined couples** in a single name field ("Doug
  Tankersley and Cindy Tankersley"), which the brief prohibits. Split into 28.
- **2 Ethnos360 records cited editorial pages** — `/magazine/stories/...` and
  `/stories/story/...` — which do not name the person and are not giving
  pages. Held with a note to re-hunt against the real pattern.
- **1 MAF record lowered to medium.** Deborah Francois shares
  `9148-zacharie-francois-ministry-support`, which names only Zacharie. A
  spouse inferred rather than cited.
- **1 Ethnos360 slug unresolved.** `bryan-and-martha-conard` did not appear in
  an independent search while two sampled siblings verified exactly. Lowered
  to medium, not dropped — likely an indexing gap.
- 6 cross-agent duplicates between the two Ethnos360 slices.

## Two things about my own process

**My audit script had a bug, and it has been running for five waves.** It read
the slug as the last path segment, so `blogs.ethnos360.org/jack-housley/about/`
resolved to "about" and every blog couple looked like a name mismatch. It
reported ten failures where there were two. Matching against the whole path
fixes it. The check has been over-reporting on any URL with a trailing
subpath since it was written.

**The no-prose-count rule did not work.** Every agent this wave read a brief
containing it and every agent still opened with a count. Ethnos360 Asia said
67 against 63 in file. The instruction is being ignored rather than followed,
which means the fix is not to reword it — it is to stop reading agent prose
and treat the file as the only input. That is what the orchestrator already
does; the rule was aimed at a reader who does not exist.
