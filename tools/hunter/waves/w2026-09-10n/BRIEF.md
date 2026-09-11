# Wave w2026-09-10n — untouched agencies, surface-discovery shape

**Agents:** 4 · **Budget:** 18 searches each

## This wave is shaped differently, and here is why

Every previous wave named an agency whose per-person giving URL I had
already confirmed, and told you to mine inside it. **I could not do that
this time.** Ten pre-dispatch probes on the obvious untouched agencies all
failed to find a readable per-person page:

| agency | what is actually there |
|---|---|
| Mission to the World | 636 support-raisers, dynamic `/missionaries/` search app |
| Wycliffe USA | paginated `?page=79` directory + opaque Missionary ID |
| TEAM | pooled GO Fund, no per-person pages |
| Pioneers | `give.pioneers.org/s-donate?firstname=…&lastname=…` form |
| Serge, Baptist World Mission | no per-person page surfaced |
| Gospel Fellowship Assoc. | ASP.NET `default.aspx?type=9&view=list` |
| Crossworld, Christar | login-gated donor portal |
| Damascus | real Support-a-Missionary index, roster rendered client-side |

These are all recorded in `hunt_negatives` — **do not re-check them.**

The static, crawlable, per-person giving page is a property of a particular
vintage of website, and we have largely harvested the ones that have it.
So your job this wave is **not** "enumerate agency X". It is:

> **Find agencies that still have a readable per-person giving page, then
> mine whatever you find, in the same run.**

That is how the best seams in this project were found in the first place.

## Method

1. **Discovery first (about 5–7 searches).** Work through your segment
   list. For each agency, one search of the shape
   `site:<domain> missionaries` / `families` / `staff` / `our-team`.
   You are looking at **URL shapes**, not at people yet. You want
   `<domain>/<something>/<first>-<last>` or `<surname-first1-and-first2>`.
2. **The moment one hits, stop surveying and mine it** with the rest of
   your budget, exactly as a normal enumeration wave: rotate qualifiers,
   read titles as well as slugs, split couples.
3. If two agencies hit, split what is left between them. If none hits,
   keep surveying and say so plainly — an exhausted segment is a finding.

## What counts as a hit, and what does not

| surface | verdict |
|---|---|
| `agency.org/missionaries/jane-smith` | **HIT — mine it** |
| `agency.org/families/smith-john-and-jane` | **HIT — mine it** |
| roster page naming people in full, no per-person page | partial: emit at `staff_directory` / `medium` |
| `?page=4`, `?id=8821`, `default.aspx?type=9` | **NOT a hit** — record and move on |
| `donate?firstname=X&lastname=Y` | **NOT a hit.** A form submission is not a page about the person |
| login / donor portal | **NOT a hit** |
| roster rendered as images or JS, no names in snippet | **NOT a hit** — record the URL so a future fetch-enabled wave has the list |

**Record a verdict in `coverage[]` for every agency you check**, hit or
miss, with the domain and what the surface actually is. The misses are half
the value of this wave.

## Segments

### `n-baptist` → `baptist.json`
Independent Baptist / fundamentalist sending agencies. **This is the
archetype that produced the best page-per-couple yield in the project**
(Baptist Mid-Missions, 116 pages carrying 206 adults). Try: Continental
Baptist Missions, Fellowship International Mission, Macedonia World Baptist
Missions, World Wide New Testament Baptist Missions, Baptist Church
Planting Ministry, Evangelical Baptist Missions, Baptist Bible Fellowship
International, Independent Faith Mission, Bible Baptist Missions,
Association of Baptists for World Evangelism regional sites.

### `n-catholic` → `catholic.json`
Catholic apostolates whose missionaries raise personal support. **The other
proven archetype** (FOCUS 5.5/query, Saint Paul's Outreach 2.7). Try:
Vagabond Missions (`vagabondmissions.com/meet-our-missionaries/` is a
confirmed live roster — start there), Christ in the City, Culture Project,
Totus Tuus, Evangelical Catholic, Corpus Christi, Youth Apostles, Miles
Christi, Mission of the Redeemer, Camp Veritas, Frassati Fellowship.

### `n-youth` → `youth.json`
US-domestic youth and campus parachurch, where staff raise their own
salary. Try: Young Life, Youth for Christ, Student Mobilization, Search
Ministries, Cadence International, Officers' Christian Fellowship,
Christian Union, Ratio Christi, Greek InterVarsity, Navigators collegiate
and Mid-America Navigators.

### `n-intl` → `intl.json`
Smaller international sending agencies. Try: World Team, Encompass World
Partners, Reach Beyond, e3 Partners, Global Frontier Missions, HeartCry
Missionary Society, InterAct Ministries, JAARS, Mission Aviation
Fellowship, Team Expansion, Pioneer Bible Translators, Resonate Global
Mission, World Gospel Mission regional sites.

## Already worked — do not re-mine

Ethnos360, World Gospel Mission, Free Methodist World Missions, BIMI,
Greater Europe Mission, One Mission Society, SEND, Converge, CMML,
Mid-Missions/BMM, Saint Paul's Outreach, FOCUS, Campus Outreach, CCO, RUF,
Avant, IBFI, MWBM, FMC. Plus everything in the probe table above.
Fellowship of Christian Athletes and NET Ministries are negatives. ABWE and
Chi Alpha are deferred, not rejected — skip them this wave.

## Everything else

Follow `tools/hunter/prompts/enumeration.md` exactly: never cite a
search-results URL or a page belonging to someone else; read the TITLE as
well as the slug, because a one-name slug is often a couple page; split
couples into two records; **a missionary's children are not missionaries**;
sensitive-region and anonymized workers go to `needs_review`, never to
`people`; never record or infer anyone's demographic or identity
attributes; no first-name-only and no first-name-plus-initial records; log
queries that found nothing; and **do not state a count in your closing
message** — the JSON file is the report.

Tier on whether the person raises personal support, not on job title.
