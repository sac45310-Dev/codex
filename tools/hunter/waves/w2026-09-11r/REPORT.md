# Wave w2026-09-11r — unprobed youth/campus ministries and federated locals

**Dispatched:** 4 agents (campus-other, chi-alpha, yfc, younglife), 18 searches each (71 used).
**Loaded:** 103 unique people · 100 coverage rows · 7 negatives · 2 new hunt_targets (Every Nation 840, Youth for Christ USA 841) · 2 existing targets updated.
**Yield:** 103 / 71 = **1.45 new people per query** — barely above the 1.3–1.4 retirement line, and the distribution is the whole story.

| agency | people | high conf | basis |
|---|---|---|---|
| Every Nation | 40 | 40 | `personal_page` |
| Youth for Christ | 37 | 1 | `staff_directory` |
| Young Life | 18 | 6 | `staff_directory` |
| Chi Alpha | 8 | 3 | mostly `staff_directory` |

**One agent carried the wave.** Every Nation alone ran ~2.2/query at full confidence on real giving pages. The three federated youth ministries together ran ~1.1/query and produced almost nothing citable to a person. That is not agent quality — all four worked their slices properly and the two weak reports are structurally honest. It is a property of federated ministries, and it is the finding worth keeping.

## The hit: Every Nation

`give.everynation.org/donate/<first>-<last>`, with a second shape `/category/missionaries/<last>-<first>`. Titles carry the full name; couples use `/donate/<first>-and-<first>-<last>` and split cleanly. Tier A is grounded in the org's own Ministry Partnership Development language (a 200-day initial support team), not inferred from job titles.

**Not exhausted, and not close.** The portal states **324 cross-cultural missionaries** plus a campus-missionary population across **1,405 campuses**; search returns the same ~40 pages regardless of qualifier rotation or exclusion sweeps. The portal exposes a paginated `offset` endpoint — that is the fetch target.

## Why the federated three under-produce

The pattern repeated independently across three agents and is now written into all three targets:

- **Young Life** has *two* surfaces that look like one. `<area>.younglife.org` subdomains are a uniform national CMS — exactly `/about/`, `/leadership/`, `/find-us/`, `/donate/`, `/contact/`, and **no per-person path at all**; roster names never reach the search index. Region sites on *independent* domains are WordPress and **do** carry `<regionsite>/regional-staff/<first>-<last>/` (confirmed on `westerngreatlakesyl.com`, not exhausted). ~50 US regions exist; trying `/regional-staff/` against each region domain is the cheap next move. The earlier pass worked the subdomains, found nothing, and marked the org **exhausted** — that flag was wrong and has been reopened to `partial`.
- **Youth for Christ** has no per-person giving URL anywhere in its chapter network: `usa.yfc.net/give` is a last-name *search form*, `give.yfci.org` keys staff by opaque `?staffId=`, chapter portals use numeric fund IDs. So 36 of 37 records are `staff_directory`/`medium` — correctly graded, not inflated. Handle: YFC USA runs a shared WordPress multisite with repeatable `/our-staff/`, `/ministries/`, `/give/`.
- **Chi Alpha** locals route donors to the national AG surface `usmissions.ag.org/MissionaryLocator/USMissionaryResult?Account=<id>` — query string plus opaque ID, so not a citable per-person page. Locals publish flat rosters, never `/staff/<first>-<last>`. The staff *are* support-raised AG U.S. Missionaries, so the tier holds; the failure is purely citation.

**The generalisation:** a federated ministry's national brand tells you nothing about whether it is mineable. What matters is whether the *locals* run their own domains. Where they do (Young Life regions, YFC chapters), there are per-person pages. Where they sit on a shared national CMS, there are none, and no amount of search budget creates them.

## Withheld and flagged

- **Mia Matchett not emitted.** The agent graded her medium and said plainly that the page-to-person mapping was inferred from result ordering plus geography — her name is in neither the URL nor the title. A citation that does not name the person is not a record; held back rather than loaded with a caveat.
- **Jay Lindell not emitted** — `/a-lasting-legacy-jay-lindell/`, "Celebrating 35 Years", reads as a retirement or memorial. Correctly caught by the agent before it reached me.
- Spouses named only in a domain or a passing clause (Bianca Gonzaga, Christian Martinez, Lauren Dean, Hannah Young, Glen Davis's wife) all went to `needs_review` under the split-on-title rule rather than being emitted.
- First-name-only staff across Chi Alpha, YFC and Young Life rosters: not emitted.
- Aggregator directories (SignalHire, ZoomInfo, TheOrg, RocketReach) were recorded in coverage specifically so a later wave does not mistake them for finds.
- One slug typo preserved deliberately: `give.everynation.org/donate/yujiko-takagi` serves "Yujiro and Natsuko Takagi". Emitted from the **title**, which is authoritative over the slug.

## Negatives recorded (7)

Officers' Christian Fellowship and Christian Union — both checked and both **Tier B**: project- and centre-funding, not personal salary support. Delight Ministries and Search Ministries — no per-person surface. Greek InterVarsity and Cru Inner City — ministry lines of parents already held, so working them would re-buy existing ground. Student Mobilization — **not an ICP negative**: its staff do raise support, but the real rosters sit on separate regional domains (`heartlandstumo.org/staff/`, `ozarkstumo.org/staff`, `pioneerstumo.org/staff`) as flat pages invisible to search. Recorded as `fetch_required`, not as a rejection.

## Data-integrity note

An `ilike '%chi alpha%'` update intended for the national target also touched **`Chi Alpha - Philly` (id 526)**, a local with no candidates. The appended note was stripped and `headcount_found`/`last_rostered_at` returned to null; `roster_status` was restored to `unrostered` — which matches its zero-candidate state but is a *reconstruction*, not a value read before the write. Targets are now updated by id, never by pattern.

## Recommendation

Every Nation is worth a second wave only behind a fetch pass on the `offset` endpoint — search has visibly capped at ~40 of 324+. The federated three should not be re-dispatched as search waves at all; the next useful move on them is `/regional-staff/` enumeration across Young Life's ~50 region domains, which is cheap and has a confirmed pattern behind it. Top fetch targets from this wave, in order: `give.everynation.org` offset endpoint, `directory.chialpha.com`, `yfc.net/chapter/`.
