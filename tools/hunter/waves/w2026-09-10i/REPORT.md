# Wave w2026-09-10i — report

Four agents, 18 searches each (72). Single target: RUF, third pass.

## Loaded

**55 people**, all Tier A. RUF now stands at **195 held**. Coverage: 72
queries, 55 URLs.

78 emitted → 2 cross-agent dupes → 21 already held → 55 new.

| agent | emitted | new | new/query |
|---|---|---|---|
| ruf-names-a | 18 | 17 | 0.94 |
| ruf-names-k | 21 | 17 | 0.94 |
| ruf-intl | 13 | 12 | 0.67 |
| ruf-codes | 26 | 9 | 0.50 |

## RUF has crossed the exhaustion line

**0.76 new/query overall**, down from 2.9 last wave. That is below the
1.3–1.4 at which WGM and FMWM were retired as exhausted, and it is the third
pass on this domain. The decline is orderly and expected: 2.9 → 0.76 as the
productive qualifiers get used up.

Recommendation: **stop enumerating RUF.** 195 held against a reported ~395 is
a good result, and the remaining ~200 are behind qualifiers that are costing
more than a search is worth. A fourth wave should be expected below 0.5.

## Why each axis faded

- **First names** (both agents, 0.94 each): the common names were spent last
  wave. The coverage shows the tail directly — Jeremy/Jesse/Joel/Jonathan,
  Keith/Kelly/Kelsey/Kevin/Kyle, Phoebe/Philip/Priscilla/Rachel/Reagan,
  Shelby/Silas/Sophia/Spencer/Stephen and Sydney/Taylor/Thomas/Timothy/Trevor
  all returned nothing.
- **Campus codes** (0.50): the worst performer, and partly self-inflicted.
  15 of its 26 records were codes already on the spent list printed in its own
  brief — `kansas`, `fsu`, `memphis`, `unc`, `unf`, `lsu`, `cnu`, `houston`,
  `ou`, `ut-austin`, `pennstate`, `tcu`, `ucf`, `rice`, `vandy`. Roughly
  half its budget bought ground we already owned.
- **RUF-International** (0.67): small but genuinely new ground. It confirmed
  the `<campus>rufi` shape the brief guessed at and took RUF-I from 6 known
  codes to 19: ugarufi, clemsonrufi, auburnrufi, berkeleyrufi, pennrufi,
  texasamrufi, utaustinrufi, utdallasrufi, columbiarufi, stlouisrufi,
  UCSanDiegoRUFI, plus the variants UFinternational and mason_ruf-i.

## Two brief changes that worked

**The grading rule landed.** Last wave an agent graded 42 of 50 campus-code
records `high` when the brief said `medium`. This wave the brief added *why* —
the page belongs to the ministry, not the person — and `ruf-intl` returned 11
of 13 correctly graded, `ruf-codes` 26 of 26. Stating the reason, not just the
rule, is what changed.

**The anti-fabrication instruction held.** `givetoruf.org/donate/<first.last>`
is a guessable shape, and agents were told never to construct a URL they had
not seen. Across 78 records there were zero search-result URLs, zero malformed
names, and every personal-slug record carried its surname in the URL.
`ruf-names-k` went further and put two people it could not cite — Kelsey, and
Leah Jardin, both named only as spouses on someone else's page — into
`needs_review` rather than emitting them. That is the behaviour the rule is
for.

## Where the project stands

| org | held | last measured new/query | status |
|---|---|---|---|
| Ethnos360 | 534 | 2.7 | geography and role both largely spent |
| RUF | 195 | **0.76** | exhausted on available axes |
| CMML | 41 | 1.1 | search-capped; roster is in a printed handbook |
| CCO | 100 | 0.28 | exhausted except the un-searched national campuses |
| Campus Outreach | 65 | 1.0 | weak |
| Avant | 12 | 0.67 | shallow, ~7 indexed profiles |

Every currently-worked domain is at or below the retirement line. The next
wave should go to **untouched agencies via verify-then-dispatch**, which is
the only method that has produced a fresh 3–5/query seam (FMC 3.7, CCO 5.0),
rather than a fourth pass on anything above.
