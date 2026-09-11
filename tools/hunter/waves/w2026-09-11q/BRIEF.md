# Wave w2026-09-11q — unprobed independent Baptist agencies

**Agents:** 4 · **Budget:** 18 searches each · **Shape:** discovery + mine

## Why this segment

Independent Baptist sending agencies are the **highest-yielding archetype
in this project**. Baptist Mid-Missions returned 116 pages carrying 206
support-raising adults. World Wide New Testament Baptist Missions,
Fundamental Baptist Missions International, BIMI, Macedonia World Baptist
Missions and Independent Baptist Fellowship International all produced.
They tend to run static sites with one page per missionary family, both
first names and the shared surname in the slug — exactly the shape search
can enumerate.

Wave n hit WWNTBM on its fourth discovery search and then ran out of
budget while still producing. It never reached the rest of the segment.
This wave is that remainder.

## Method

1. **Discovery (about 5–7 searches).** One `site:<domain> missionaries`
   or `families` or `staff` per agency. You are reading **URL shapes**,
   not people yet. You want `<domain>/<path>/<first>-and-<first>-<surname>`
   or similar.
2. **The moment one hits, stop surveying and mine it** with the rest of
   your budget.
3. Record a verdict in `coverage[]` for **every** agency you check, hit or
   miss, naming the domain and what the surface actually is.

## What counts as a hit

| surface | verdict |
|---|---|
| `agency.org/missionaries/john-and-jane-smith` | **HIT — mine it** |
| roster naming people in full, no per-person page | `staff_directory` / `medium` |
| `?page=4`, `?id=88`, `default.aspx?...` | not a hit — record and move on |
| `donate?firstname=X&lastname=Y` | not a hit; a form is not a page about a person |
| login-gated, or roster rendered as images/JS | not a hit — record the URL for a fetch pass |

## Slices

### `q-baptist-a` → `baptist-a.json`
Evangelical Baptist Missions (`ebm.org`), Baptist Bible Fellowship
International (`bbfi.org`), Baptist International Outreach, Baptist
Faith Missions.

### `q-baptist-b` → `baptist-b.json`
**Continental Baptist Missions — find its real domain first.** Wave n
probed `cbmin.org`, which is Canadian Baptist Ministries, so this agency
has never actually been tested. Try `cbmissions.org`, `continentalbaptist
missions.org` and a plain name search. Then Baptist Church Planters
(`bcpusa.org`), Independent Faith Mission (`ifmmissions.org`).

### `q-baptist-c` → `baptist-c.json`
Bible Baptist Missions, Baptist Mid-Missions Canada, Baptist World Mission
regional sites, Gospel Fellowship Association regional, Fellowship of
Independent Missions (`fimusa.org` — note wave n probed `fim.org` which
returned nothing, the correct domain may differ), Berean Mission.

### `q-baptist-d` → `baptist-d.json`
Free discovery across the segment: find independent Baptist and
fundamentalist sending agencies **not named above** and test their
surfaces. Good search handles: "independent Baptist mission agency"
missionary support deputation; "our missionaries" Baptist mission board;
`"/missionaries/"` Baptist agency deputation furlough. Mine whatever hits.

## Already worked — do not re-mine

See `tools/hunter/WORKED.md`. In this segment specifically: **Baptist
Mid-Missions (206), BIMI (153), WWNTBM (98), Fundamental Baptist Missions
International (87), Macedonia World Baptist Missions (43), Independent
Baptist Fellowship International (38)**.

Recorded as dead in `hunt_negatives`, do not re-probe: Baptist World
Mission (article-driven, no per-missionary page), Gospel Fellowship
Association Missions (ASP.NET query-string directory), Fellowship
International Mission at `fim.org` (no `/missionaries/` path indexed),
Baptist Church Planting Ministry `bcpm.org` (keyed by church-plant
location, not person).

## Standing rules that bit hardest recently

- **Split couples on the TITLE, never the slug.** A two-name slug can
  outlive one of the two people — wave o caught six such pages on one
  domain, and this segment is exactly where memorial rewrites happen.
- **Exclusion sweeps degrade rather than fail.** Past ~10 negative terms
  the engine silently drops the operators and re-serves excluded names.
  An identical result set is the stop signal.
- **Prefer `allowed_domains` over `site:`** on small domains — bare
  `site:` gets hijacked by Wikipedia when a query carries a place or
  saint name.
- Never cite a search-results URL or someone else's page. Children are
  not missionaries. Anonymized, initials-only or sensitive-region workers
  go to `needs_review`. Never record or infer demographic or identity
  attributes. Log queries that found nothing. **Do not state a count in
  your closing message.**
