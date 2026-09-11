# Wave w2026-09-11p — Ratio Christi, Youth Apostles, Women Youth Apostles

**Agents:** 4 · **Budget:** 18 searches each

Three small-to-mid targets, all found late in wave n and none properly
mined.

## Target 1 — Ratio Christi (2 of ? held)

**Pattern (confirmed):** `give.ratiochristi.org/missionary/<first>-<last>`,
plus a parallel per-chapter shape and a full chapter index. Apologetics
ministry with chapters at universities across the US and internationally.

**THIS ONE NEEDS SCREENING, AND IT IS THE POINT OF THE SLICE.** Ratio
Christi runs **volunteer tent-maker chapter directors** alongside
personally supported missionaries. A volunteer is not an ICP fit — they
have no donor base to manage, which is the entire product. Do not bulk-
grade this roster Tier A.

| what the page shows | verdict |
|---|---|
| a `give.ratiochristi.org/missionary/<name>` page with a support ask | **Tier A**, `personal_page` |
| named chapter director, no giving page, no support language | `needs_review` — say "volunteer or supported unknown" |
| explicitly volunteer, bivocational, or "tent-maker" | **do not emit**; log as a screening exclusion |

If the split is not resolvable from titles and snippets, say so plainly
and put the person in `needs_review`. A wrong Tier A here is worse than a
miss, because it puts a volunteer into a sales queue.

## Target 2 — Youth Apostles (8 held)

**Pattern:** flat concatenated slugs at the SITE ROOT —
`youthapostles.org/tylerfabian`, not `/missionaries/tyler-fabian`. Titles
are `First Last | Youth Apostles`.

**Known structural problem:** a root-level slug gives the search engine no
path prefix to enumerate, so every `site:` query returns the same handful
of person pages mixed with program and blog pages, and `-surname`
exclusions were flatly ignored three times running. Wave n got 8 people
from 11 searches for exactly this reason.

Do not repeat that. Try instead: the title suffix `"| Youth Apostles"` as
a literal string; role words (apprentice, brother, formation, campus
minister, chaplain); the Arlington/Virginia diocese context; school names
(St. Paul VI, Bishop O'Connell, Virginia Tech); and `/officestaff` and
`/missionaries` as named hub pages.

## Target 3 — Women Youth Apostles (0 held)

`womenyouthapostles.org` — a separate sister community, never probed.
Establish whether it has a per-person surface at all before mining. If it
does not, say so and spend the remainder on target 2.

## Slices

### `p-ratio-a` → `ratio-a.json`
Ratio Christi, chapters A–M by university name, plus the national chapter
index. Screen every person per the table above.

### `p-ratio-b` → `ratio-b.json`
Ratio Christi, chapters N–Z by university name, plus staff/leadership and
international chapters. Screen every person per the table above.

### `p-youth-apostles` → `youth-apostles.json`
Youth Apostles remainder, using the title-suffix and role axes rather than
bare `site:` queries.

### `p-women-ya` → `women-ya.json`
Women Youth Apostles first (surface discovery, then mine if it hits). If
it has no per-person surface, spend the rest on Youth Apostles from a
different angle than your sibling — school and parish names, and the
Arlington diocesan context.

## Standing rules that bit hardest recently

- **Split couples on the TITLE, never the slug.** A two-name slug can
  outlive one of the two people. Wave o caught six such pages on one
  domain.
- **Exclusion sweeps degrade rather than fail.** Past ~10 negative terms
  the engine drops the operators and re-serves excluded names. An
  identical result set is the stop signal, not a reason to buy more.
- Never cite a search-results URL or someone else's page. Children are not
  missionaries. Anonymized or initials-only people go to `needs_review`.
  Never record or infer demographic or identity attributes. Log queries
  that found nothing. **Do not state a count in your closing message.**

Already worked, do not re-probe: see `tools/hunter/WORKED.md`.
