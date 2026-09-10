# Wave w2026-09-10i — RUF continuation

Rendered from `tools/hunter/prompts/enumeration.md`. Four agents, 18 searches
each (72). Single target. Model: Haiku 4.5.

## Why RUF again

It is the only target still paying. w2026-09-10h: RUF 2.9 new/query against
CCO 0.28. We hold **140** against a reported roster of ~395 (170 campus
ministers, 49 campus staff, 176 interns), and 49 of the 140 are interns found
in a single agent last wave.

Both productive axes are far from spent:

- **First names.** Only twelve have been searched — sarah, hannah, emily,
  katie, jacob, john, grace, matt, sam, will, ben, drew. Two of those returned
  nothing; the other ten produced 55 records.
- **Campus codes.** About 60 are spent against roughly 170 RUF ministries.

## The held list below is a PLANNING HINT, NOT A FILTER

Last wave a brief listed held surnames and an agent used it to exclude any
person whose surname matched. That is wrong: two different people can share a
surname, and the rule would silently discard a real find. **Never drop a
person because their surname appears here.** Use the list only to choose which
qualifiers are worth spending a search on. The orchestrator dedupes at ingest;
that is not your job.

**Held slugs** (do not re-buy these as qualifiers):
adelyn.sun adriana.fernandez alana.kelley andy.reed anna.boyd anna.plybon
ashley.vandixhoorn ava.concannon ben.pate brittonwood Caleb.sklena
christina.mcwhite devin.phandara ecartledge edgar.galvan emily.wilson
emilywilliams evan.england grace.beckham grace.kreul grace.mautz Grace.Nelson
grace.potter gracehoyme Hannah.murphy hannah.sandridge hannah.sung hhumphreys
Jackie.Lee Jacob.Hatfield jake.mancuso jasonlittle jiwon.kim joanna.woo
john.ahlin Johnathan.Smith johnpearson josh.dailey jrfoster kamryn.holleman
kelley.vanhaitsma kyusik.choi laurastraka Lauren.Danforth laurian.lien
luke.wilkerson madeline.custer mary.leuenberger matt.holdsworth mikaela.sesler
mitchell.cloutier molly.kerr nate.gibson nick.molicki niko.fannin noah.brown
noah.hendrick noel.coppedge Paige.jackson reuben.stecher riley.tarter
sam.jones sam.stackler sara.larson will.custer will.hamill will.schaufelberger

**Held campus codes** (spent — do not re-buy):
appstate arizona auburn bama belhaven belmont boisestate brownrisd charlotte
clemson cnu columbus davidsoncats duke ecu fgcu fsu furman gatech gators gsu
hailstate houston indianauniversity jacksonville jmu kansas KentSt lehigh
liberty longbeachst lsu memphis mercer NCCU ncsu ncsurufi
northwestern-international olemiss ou pennstate pitt purdue rhodes rice
rufarkansas rutgers samford sjsu smuint southernmiss stanford tcu trinity tsu
uab ucf ucfrufi ucla unc unf usc usf ut-austin utarlington utk utkrufi uva uw
vandy vandyrufi vt wofford

## Surfaces

  https://givetoruf.org/donate/<first.last>   -- a person. Surname in slug +
      name in title = `high`, evidence `personal_page`.
  https://givetoruf.org/donate/<campus-code>  -- the ministry giving page for a
      campus, which names its minister. **Grade `medium`, evidence
      `staff_directory`** — the page belongs to the ministry, not the person,
      and say so in fit_reason. Last wave an agent graded 42 of these `high`
      and all had to be corrected at ingest.

ruf.org itself has NO per-person pages. Settled two waves ago — do not re-test.

## Assignments

| agent | slice |
|---|---|
| `ruf-names-a` | personal slugs, first names A–J |
| `ruf-names-k` | personal slugs, first names K–Z |
| `ruf-codes` | campus codes not in the spent list, weighted to small and regional colleges |
| `ruf-intl` | RUF-International: `*rufi`, `*int`, `*-international` codes and international-student ministry |

## Tiering

RUF campus ministers, campus staff, area coordinators and interns all raise
full personal support: **Tier A**, without exception. Do not downgrade on job
function or location.

Do not emit students. An intern is staff; a student attending RUF is not.

## Watch for fabrication in your own output

`givetoruf.org/donate/<first.last>` is a guessable shape. Do not construct a
URL you have not seen in a result. If a name appears in a snippet but you did
not see its page URL, cite the page you actually saw and grade accordingly, or
put it in `needs_review`.
