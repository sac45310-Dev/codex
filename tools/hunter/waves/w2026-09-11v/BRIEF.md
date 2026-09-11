# Wave w2026-09-11v — Baptist Bible Fellowship International (BBFI)

`bbfimissions.com`, hunt_target priority **94** — recorded in wave q as the
biggest untouched seam found since FOCUS. **700+ missionaries in 80+ nations,
only 8 held.**

## Pattern — confirmed by orchestrator probe, do not re-verify

`bbfimissions.com/missionary/<slug>`. The working query shape is
**`site:bbfimissions.com/missionary <qualifier>`** — one country qualifier
returned nine distinct per-person pages with clean titles.

**Two slug shapes are used interchangeably on the same site:**

| shape | example | title |
|---|---|---|
| `<first>-and-<first>-<surname>` | `/bob-and-sandy-piatt` | Bob and Sandy Piatt |
| `<surname>-<first>-and-<first>` | `/wyatt-michael-and-cristy` | Michael and Cristy Wyatt |
| `<first>-<surname>` (single) | `/bill-hathaway`, `/george-king`, `/ruth-king` | Bill Hathaway |

Wave q's agent went **0-for-8 guessing slugs** at this agency. That is the
dual-shape problem, and the fix is not smarter guessing — it is to stop
guessing. **Rotate qualifiers and read what comes back.** This is exactly what
worked at Wycliffe, where the same nine-shape problem produced 302 people once
guessing was abandoned.

## THE CRITICAL TRAP AT THIS AGENCY — read before your first search

BBFI pages state an **approval date**, and the probe returned approvals from
**May 1960, September 1966, May 1974, May 1984**. This is a very old roster.

- **An approval date in the 1960s or 1970s means the person is probably retired
  or deceased.** A missionary approved in 1960 would be around ninety now.
- **`/george-king`** is titled for George alone and the page refers to
  *"the late Ellen King"* — a surviving spouse on a page that names a deceased
  one. Emit George, never Ellen.
- **A single-name page at this agency is often a widow or widower**, not a
  single missionary. Read the page text before assuming.
- BBFI also publishes a **"Heroes of the Faith"** path. Anything reached
  through it is a memorial. Treat it as a death flag, and **withhold surviving
  spouses reached that way too** — a memorial article is evidence about the
  deceased, not evidence that the survivor is currently serving.

**Rule for this wave:** if the approval date is before 1990 and the page states
no current activity, put the record in `needs_review`, not in `people`.
Emitting a deceased person as a sales prospect is the worst error in this
pipeline, and this agency is the most likely place in the whole project to
make it.

## Already held — do not re-emit

Only 8 people so far. Known slugs: `nolan-and-janay-letourneau`,
`wyatt-michael-and-cristy`. Exclude surnames as results repeat, 8-10 per query.

## Slices — non-overlapping by region

- **v-asia** — Japan, Philippines, Taiwan, Korea, Thailand, Indonesia,
  Singapore, Malaysia, India, Cambodia, Guam, Micronesia.
- **v-latam** — Mexico, Brazil, Peru, Argentina, Chile, Colombia, Venezuela,
  Guatemala, Honduras, Costa Rica, Panama, Paraguay, Uruguay, Dominican
  Republic, Puerto Rico.
- **v-africa-europe** — Kenya, Ghana, Nigeria, South Africa, Uganda, Zambia,
  Tanzania, Ivory Coast, Togo, Benin; plus Germany, Spain, Portugal, Italy,
  France, UK, Ireland, Poland, Romania, Ukraine.
- **v-roles** — no country qualifiers. Rotate: church planter, Bible college,
  radio, literature, camp, deaf ministry, aviation, medical, orphanage,
  national pastor training, church planting team, "approved as missionaries",
  "on deputation", "field director", "regional director".

`bbfimissions.com/missionaries?show=all` remains the single highest-value fetch
target in the project if page fetching ever becomes possible — it would return
the whole roster in one read.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
