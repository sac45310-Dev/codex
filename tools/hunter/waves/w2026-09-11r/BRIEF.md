# Wave w2026-09-11r — youth and campus parachurch, plus federated locals

**Agents:** 4 · **Budget:** 18 searches each

Wave n's stop-and-mine rule fired on its first search in this segment, so
most of it was never reached. These organisations are **unprobed, not
negative.**

## The federated angle, which has never been tested

Young Life (36 held) and Youth for Christ (25 held) are both **federated**:
local areas and chapters run their own sites, their own staff pages and
often their own giving. The national sites have been looked at; the
**local-area sites have not**, and that is where per-person pages usually
live in a federated org.

This is the same structural insight that opened FOCUS — the campuses
published what the national site would not. Chi Alpha was deferred in an
earlier wave for exactly this reason and is fair game here.

## Slices

### `r-younglife` → `younglife.json`
Young Life local areas. `younglife.org` is national; the yield will be in
area sites and area staff pages. Try `<city>.younglife.org`,
`<area>younglife.org`, "Young Life <city> staff", "Young Life area
director <state> support", and Young Life's own area-finder if one
surfaces. Also Young Life College, WyldLife, Capernaum and YoungLives,
which run their own staff.

### `r-yfc` → `yfc.json`
Youth for Christ local chapters. `yfc.net`/`yfci.org` are national. Try
`<city>yfc.org`, "Youth for Christ <city> staff", City Life, Juvenile
Justice Ministry, Campus Life, Parent Life — each runs its own staff. Also
test whether YFC chapters use a common giving platform with per-person
pages.

### `r-campus-other` → `campus-other.json`
Named organisations nobody has tested: Search Ministries
(`searchministries.org`), Officers' Christian Fellowship (`ocfusa.org`),
Christian Union (`christianunion.org`), Greek InterVarsity, Every Nation
Campus, Delight Ministries, Cru Inner City. Discovery + mine.

### `r-chi-alpha` → `chi-alpha.json`
Chi Alpha Campus Ministries — **deferred in an earlier wave, not
rejected.** Its staff do raise personal support; the obstacle was that it
is federated with no national per-person surface. That is exactly what
this wave is for. Work the district and campus sites: `chialpha.com` is
national, but try `<state>chialpha.org`, `xa<campus>.org`, "Chi Alpha
<university> staff", "Chi Alpha missionary support <name>". If a district
site shows a per-person giving slug, mine it.

## Method

Discovery then mine, as usual: ~5–7 searches reading **URL shapes**, then
stop surveying and mine the first real hit. Record a verdict in
`coverage[]` for every organisation and every local site you check.

For federated targets specifically: **one good local site is a hit.**
Mine it, and record the URL pattern, because it will usually repeat across
that org's other locals — that repeatable pattern is worth more than the
people from any single area.

## What counts as a hit

`org.org/staff/jane-smith` or `give.org.org/<first>-<last>` → mine it.
A roster naming people in full with no per-person page → `staff_directory`
/ `medium`. Query-string forms, numeric IDs, login walls, or rosters
rendered as images → not a hit; record the URL for a fetch pass.

## Already worked — do not re-mine

See `tools/hunter/WORKED.md`. In this segment: **RUF (222), Coalition for
Christian Outreach (119), FOCUS (522), Campus Outreach (35 + regional
rows), Cadence International (204, retired), Ratio Christi (59), Saint
Paul's Outreach (49), InterVarsity (23), Navigators (6)**.

Recorded dead, do not re-probe: Navigators Collegiate
(`collegiatenavigators.org`, giving keyed to campus not person),
Mid-America Navigators (flat brochure site), Student Mobilization
(login-gated nationally — **but campus subdomains like
`tcu.stumo.org/staff.html` carry flat rosters and are worth one search**),
Fellowship of Christian Athletes, NET Ministries.

## Standing rules

Split couples on the TITLE, never the slug. Exclusion sweeps degrade past
~10 terms — an identical result set is the stop signal. Prefer
`allowed_domains` over `site:` on small domains. Never cite a
search-results URL or someone else's page. Children are not missionaries.
Anonymized or initials-only people go to `needs_review`. Never record or
infer demographic or identity attributes. Log queries that found nothing.
**Do not state a count in your closing message.**
