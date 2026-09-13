# Negative search operators — tested, 2026-09-12

Two contradictory claims had accumulated in `prompts/enumeration.md` and neither
was ever tested:

- Waves q–u: *"exclusion lists work but hit a ceiling of ~10–12 terms."*
- Wave w2026-09-12c: *"negative operators are ignored by this backend entirely."*

**Both are wrong.** 14 controlled searches, baseline-versus-variant, below.

## Verdict

| mechanism | works? | evidence |
|---|---|---|
| `blocked_domains` parameter | **yes, every time** | removed `jaguar.com` and `en.wikipedia.org` completely |
| `allowed_domains` parameter | **yes** | used successfully by a wave-c agent |
| bare token `-surname` | **often, not reliably** | worked in 5 tests, failed in 4 |
| `-"quoted phrase"` | **no — and it backfires** | `-"Terry Yu"` moved Terry Yu to result #1 |
| `-site:domain.com` | **no** | `jaguar -site:jaguar.com` still returned jaguar.com twice |
| 2-character tokens (`-Yu`) | **no** | failed twice; Terry Yu and Yu-kuang Chang both survived |

**Use `blocked_domains`. It is the only mechanism that worked every time.**

## What the tests showed

### Bare-token negatives do work — the "inert" claim is wrong

Baseline `site:internationalstudents.org/team Campus Staff` returns Lassiter,
Casper, Mull, Yu, Parlette, Billings, Tse, Jackson, Mosher.

- `-Mosher -Lassiter -Casper` → **all three gone**, three new people surfaced
  (Patricia Bull, Jessica Wang, Claire Duckett).
- `-Parlette -Billings -Tse` → **all three gone**, Lassiter/Casper/Mosher back.
- Without `site:` at all: `"International Students Inc" campus staff -Mosher
  -Parlette -Billings` → Parlette and Mosher gone, result set almost entirely
  different.

Exclusion is real, and it does not require the `site:` operator.

### There is no ~10–12 term ceiling — that claim is wrong too

- **12 negatives** → all 12 excluded, 8 new people surfaced.
- **20 negatives** → all excluded, same clean behaviour.

The earlier waves' "ceiling" was almost certainly **term-specific failures being
read as a count limit**. Nothing degraded at 20.

### But they fail unpredictably

On a different corpus the same syntax did nothing:

- `jaguar -car -automobile -vehicle` → every car result stayed, and it *added*
  one (Jaguar X-Type).
- `jaguar -Instagram -Models` → the Instagram page and the "All Models" page
  both stayed, despite those exact words being in their titles.
- `jaguar animal habitat -Wikipedia -Geographic` → `-Wikipedia` worked,
  `-Geographic` did not; National Geographic stayed.

**I could not establish a rule separating the successes from the failures.**
I disproved the obvious candidates: it is not head-query caching
(`jaguar qwertyuiop` returned a completely different result set, so the backend
does evaluate the full query), it is not a `site:`-only feature, and it is not
title-versus-body matching (`-Models` failed against a title containing
"Models", while `-Lassiter` succeeded against a title containing "Lassiter").

Treat inline negatives as **best-effort**: worth using, never worth trusting.
Verify that a name you excluded is actually absent before concluding anything
from its absence.

### The tool's own summary lies about this — in both directions

This is how four waves came to hold a false belief without anyone testing it.

- On `-Zeigler`, which changed nothing, the summary said: *"These results
  exclude profiles containing 'Zeigler' as specified in your search query."*
- On `-Mosher -Parlette -Billings`, which **worked**, the summary said: *"those
  exclusion parameters aren't supported in this search tool format."*

**The prose summary is not evidence.** Read the URL list. Agents should be told
this explicitly.

## Reference: negative operators in web search

Verified here against this backend. Others are standard syntax that this
backend does not honour.

| operator | meaning | this backend |
|---|---|---|
| `-term` | exclude documents containing the term | best-effort — often works |
| `-"exact phrase"` | exclude an exact phrase | **no**, and can promote the target |
| `-site:example.com` | exclude a domain | **no** — use `blocked_domains` |
| `-inurl:word` | exclude by URL substring | not honoured |
| `-intitle:word` | exclude by title | not honoured |
| `-filetype:pdf` | exclude a file type | not honoured |
| `-intext:word` | exclude by body text | not honoured |
| `-related:` / `-cache:` | not negatable in any engine | n/a |
| `NOT term` | Boolean NOT (Bing/library syntax) | not honoured |
| `AND NOT` / `!term` | other Boolean dialects | not honoured |

The tool's own parameters are the supported path:

| parameter | effect |
|---|---|
| `blocked_domains: ["a.com","b.org"]` | hard-excludes those domains — **reliable** |
| `allowed_domains: ["a.com"]` | restricts to those domains — reliable |

## Consequences for the hunter waves

1. **The exclusion-ceiling rule in `enumeration.md` was wrong and is corrected.**
   Agents were told to cap exclusions at 8–10 surnames. Twenty work fine.
2. **Wave c's "inert" finding was wrong and is corrected.** It generalised from
   one failed attempt on one axis.
3. **Neither error was caught for weeks** because the tool's summary asserted
   whichever answer the agent already believed. The lesson is broader than
   search operators: *a natural-language summary of a tool result is not a tool
   result.*
4. Domain exclusion — the thing waves actually needed when Wikipedia
   college-sports pages crowded out `site:` queries — was available the whole
   time as `blocked_domains`, and no wave used it.

## The wave-c "football team" collision, revisited

Wave c lost 15 of 24 queries on the university axis because
`site:internationalstudents.org/team` collides with "*University* football
team". Its own conclusion was that nothing could be done because negatives are
inert.

**`blocked_domains: ["en.wikipedia.org"]` would have fixed it.** That is the
single most costly consequence of the untested belief, and it is worth
re-testing that axis before ISI is treated as finally closed.
