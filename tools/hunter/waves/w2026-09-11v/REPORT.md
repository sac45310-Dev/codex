# Wave w2026-09-11v — Baptist Bible Fellowship International

**4 agents, 72 searches. 172 unique people found, 170 loaded.**
**Yield 2.4 new people per query** — comfortably above the 1.3–1.4 retirement line.
BBFI goes from 8 held to 178.

## The wave-q problem was solved by giving up on slug guessing

Wave q recorded BBFI as the biggest untouched seam since FOCUS but only extracted
8 people, because its agent spent the budget **guessing URLs and went 0-for-8**.
The agency uses multiple slug shapes, so guessing cannot work.

The fix was not smarter guessing. It was `site:bbfimissions.com/missionary <qualifier>`
— one country qualifier returns 7–10 distinct per-person pages with clean titles.
Exactly the lesson Wycliffe taught in wave t, applied deliberately here.

**Four slug shapes are in use, not the two the brief predicted:**

| shape | example |
|---|---|
| `<first>-and-<first>-<surname>` | `/bob-and-sandy-piatt` |
| `<surname>-<first>-and-<first>` | `/wyatt-michael-and-cristy`, `/schoening-dawson-and-kayla` |
| `<first>-<surname>` | `/bill-hathaway`, `/karen-kolb` |
| `<surname>-<first>-church-planter` | `/adkins-sean-church-planter` (domestic APEX) |

## Age is the defining feature of this agency

BBFI publishes an **approval date** on every page, and they run back to **1958**.
This is by far the oldest roster the project has worked, and it is the reason
**80 of 252 records were routed to `needs_review`** rather than emitted.

The agents applied the rule correctly and with judgement. Only 7 loaded records
carry a pre-1990 date, and each has an explicit current-activity statement:

- **Mike Ivey** — approved Korea 1986, but "working since 1986, permanently relocated to Jeju"
- **Paul Byars** — approved 1975, resigned 1990, **reinstated 1992**
- **Ray Crocker** — approved Korea 1979, **transitioned to Singapore 1993**
- **Wesley Lane** — approved 1987 Haiti, moved to the Dominican Republic 1998, ministry continuing

That is the distinction that matters, and it is the same one wave t had to learn
the hard way: *an old date is not a disqualifier; an old date with no current
activity is.*

**A single-name page at BBFI is frequently a widow or widower, not a single
missionary.** `/george-king` is titled for George alone and the page names
*"the late Ellen King"*. Agents surfaced several of these (Frances Lingo, Lucy
Smith, Lynda Todd, Wilma Surrett) by spotting the title/slug mismatch, and
routed them for review rather than emitting a deceased spouse.

One inference was deliberately not recorded as fact: an agent described Jane
Coley as "likely widowed but actively serving". She is emitted — she is the
named, active person on her own page — but the widowhood guess is kept out of
the data.

## Not exhausted, with a caveat

104 distinct person-pages reached against a stated **700+ roster**.

Africa and Europe came back strikingly thin: Nigeria, Ghana, Uganda, Zambia,
Tanzania, France, Germany, UK, Poland, Czech Republic and Hungary all returned
nothing. That may be a genuine absence — BBFI's historic concentration is Asia
and Latin America — or an indexing gap. It is recorded as `no_people` coverage
either way so the next wave does not re-buy it blind.
