# Roster wave w2026-09-09c — sending agencies

Date: 2026-09-09. Eight Haiku 4.5 roster agents, 15 searches each (118 executed),
against the top of the queue after the Tier-A re-ranking.

## Results

**156 people ingested — 141 Tier A**, nearly all citing a personal giving page.
That is more Tier A in one wave than the previous nine combined (191 total
before this wave).

| org | people | Tier A | giving pattern found |
|---|---|---|---|
| Resonate Global Mission | 61 | 59 | `resonateglobalmission.org/missionaries/<names>` |
| CMF International | 21 | 21 | `give.cmfi.org/donate/<name>` |
| Greater Europe Mission | 19 | 18 | `gemission.org/give/<ID>/` |
| Free Methodist World Missions | 17 | 17 | `fmwm.org/<region>/<lastname>/` |
| SEND International | 17 | 17 | `send.org/give/missionaries/<lastname>` |
| Campus Outreach Atlanta | 9 | 9 | `coatlanta.org/<name>` |
| Multiply | 8 | 0 | **none — centralized model** |
| AGWM | 4 | 3 | poorly indexed |

## Pattern-first is the whole result

Every agent was told to find the per-person giving URL scheme *before* hunting
names. Six of eight found one in their opening searches and spent the rest
enumerating inside it. The yield difference is stark: agencies where the pattern
was found returned 9–61 people each; the two where it was not returned 4 and 0
Tier A.

This is the ReachGlobal finding generalized, and it should now be the default
opening move for any sending agency: **find the pattern, then mine it.**

## Multiply: the negative that carries information

Multiply ranked identically to SEND and GEM and returned **zero Tier A**. It
runs a centralized, org-managed support model — there are no per-person giving
pages to find. Its record is corrected to `tier_profile: B` with the finding in
notes, and its stale `mbmsint.org` domain updated to `multiply.net`.

This is the funding-model distinction the entire ICP rests on, it is invisible
from org type or size, and it is only discoverable by looking. Worth checking
early on any agency before spending a full budget on it.

## Orchestrator corrections (11)

Applied on top of committed raw output, so each is a reviewable diff.

- **Campus Outreach Atlanta left 3 couples as single records** — split into 6
  individuals, giving 9 people from 6 rows.
- **GEM's "Gene W" and "Inga W"** — truncated surnames cannot differentiate a
  person; moved to `needs_review` with their (real) giving URLs, so they are
  mineable once the full names are known.
- **FMWM's "Wendi" and "Joanne"** — single tokens from couple pages
  (`/asia/jason-wendi/`, `/middle-east/hany-joanne/`); same treatment.
- **AGWM gave Zach Rix and Zachariah Brinegar the same giving URL** while its
  own report cited different account numbers. Rix's URL dropped and confidence
  lowered rather than guess which citation was wrong.
- **Resonate's 3 Tier B cite a homepage or section page**, not a page naming
  the person — dropped to `low` confidence with a verify note.

## A claim that did not survive checking

Resonate's agent reported "73 individuals". The file contains 62, and 61
survived ingest. The summary inflated its own result. The *records* were sound —
36 distinct giving pages, couples correctly split, every name matching its URL
slug — but the prose overstated by 18%. Audit the file, never the summary.

## Outstanding

- **Every pattern found is under-mined.** GEM's giving directory has at least 17
  pages; CMFI fields 150+ missionaries against 21 found; AGWM has ~2,000 and
  poor indexing. A follow-up pass that walks pagination rather than searching
  names would multiply this wave several times over.
- **Campus Outreach Atlanta parentage** — the agent describes it as a ministry
  of Perimeter Church, which would make it a program rather than an addressable
  org, though staff-designated giving argues otherwise. Settle before rostering
  the other nine chapters.
