# Wave w2026-09-22a — giving-domain screen of the org-triage promotions

**Question asked of each organisation:** does its own giving or staff surface
list individual people, or only programmes? An organisation qualifies only if
its site carries per-person pages. Funds, projects, regional appeals and
general donation forms mean the roster lives somewhere else.

**Status: incomplete.** 151 of 221 organisations were screened. The remaining
70 were never searched.

## What was screened, and what was cut before searching

The 283 targets carrying `discovered_by='org-triage:2026-09-13'` and
`roster_status='unrostered'` went through the rubric in ORG-TRIAGE-PLAN §4.D,
whose steps run in cost order. 62 were disqualified for free before any search:

| cut | n | examples |
| --- | ---: | --- |
| business_vendor | 22 | counselling practices, hospices, a television network, an LLC, a curriculum publisher |
| denomination | 16 | AG / EFCA / Foursquare district offices, state ministry networks |
| school_salaried | 14 | preschools, seminaries, universities |
| faith_review | 7 | interreligious and ecumenical bodies — owner's call, not an agent's |
| person_shaped | 3 | rows literally named `Planter: <name>` |

The regex mislabelled several, which were put back into the test set by eye:
**MOPS International** (caught by the word "preschool" — it is a mothers'
ministry), **two FCA regions** and **ELCA Campus Ministry Network** (campus
and athletics staff typically do raise support), **Hospital Chaplains
Ministry of America** (caught by "hospital"), **Center for Women's
Ministries** (caught by a trailing "Inc."), **Wheaton College Billy Graham
Center**, **Sunset International Bible Institute**, **Foursquare Multiply**
and the **Creation Festival Foundation**. This is the "never sweep on a
keyword alone" rule doing its job.

## Result

| verdict | n |
| --- | ---: |
| programmes | 111 |
| unknown | 87 (of which **70 were never searched**) |
| no_domain | 9 |
| none | 7 |
| **people** | **5** |
| **few_people** | **2** |

**Seven hits out of 151 screened, a 4.6% rate.** Even if every one of the 70
unscreened rows were a hit, which is wildly implausible given the pattern,
this cohort is overwhelmingly not ICP.

### The hits, with caveats

| id | organisation | verdict | note |
| --- | --- | --- | --- |
| 1629 | Serge | people | `give.serge.org/donate/<person-name>`, 5 distinct. The cleanest hit. |
| 1562 | Mission to North America (PCA) | people | `give.pcamna.org/to/<id>/` titled with named workers and planters, 4 seen. |
| 1552 | Man in the Mirror | people | `/areadirectors/<name>/`, 4 seen; giving invites supporting a local Area Director. |
| 1438 | Center for Indian Ministries | people | 3 `/staff/<name>` pages plus a give page routing gifts to a missionary family. |
| 1452 | Christos Center | people | 3 named pages, **but** its own donate page is programme-based. These are staff bios, not giving pages. Weakest of the five. |
| 1590 | Pioneers | few_people | See the methodological finding below. Almost certainly a false negative on volume. |
| 1478 | Eternity Sports | few_people | 2 named `/athletes/` URLs that read as testimony profiles, not support-raising staff. |

## Methodological finding: path-only matching undercounts

Pioneers exposes per-person giving as **query parameters**, not path segments:
`give.pioneers.org/s-donate?ProjectCode=…&firstname=…&lastname=…`, behind a
"Give to a Missionary" hub. The screen's rule — a person's name in the URL
path — cannot see that shape, so Pioneers scored `few_people` when it is
plainly a support-raising agency.

**Any agency on that donation platform will be systematically undercounted.**
The test needs a query-parameter rule before it is trusted on a large cohort.
Two more rows showed the same shape from the other direction: IHOP Kansas City
and Lifesong for Orphans both have real per-person designation behind a search
form or an eGiving code, with nothing indexed. Both were honestly recorded as
`unknown` rather than `none`.

The inverse error also appeared. **PlanterMatch** and **Praxis Labs** both have
named `/coach/<name>` and `/entrepreneurs/<name>` pages that are third-party
directory bios, not the organisation's own support-raised staff. A rule that
auto-promotes named paths would have wrongly qualified both.

## Why 70 rows were never searched

All eight agents shared one session-wide web-search budget of 200 calls, which
was exhausted partway through. Batches 5 through 8 ran mostly dry, and every
affected row carries a note reading `NOT SCREENED` so it can never be mistaken
for a real verdict. Agents correctly refused to fall back to direct fetching:
the egress proxy denies these domains, and a policy denial is reported, not
routed around.

**To finish:** re-run the 70 with a raised search budget. They are identifiable
as rows whose `note` contains `NOT SCREENED`.

## Data-quality corrections found along the way

The stored website is wrong or dead on at least 29 rows. Worth applying
regardless of what happens to the screen.

Wrong domain, correct one found: 1423 → arcchurches.com · 1442 → ciy.com ·
1450 → csfindy.com · 1453 → cocipm.org · 1456 → optionspregnancycenter.org ·
1465 → deaf316.org · 1466 → deafkidsconnect.com · 1468 → diamondjcowboy.com ·
1487 → .org not .com · 1494 → fatherhoodcomission.com (one "m") ·
1499 → foursquaremultiply.org · 1510 → .org not .com · 1520 →
heartboundministries.com · 1525 → hopeforthenations.com · 1537 →
joinedtohashem.org · 1540 → kingdomstorycompany.com · 1551 →
madetoflourish.org · 1553 → mchapusa.com · 1595 → plantermatch.org ·
1610 → reasons.org · 1662 → thekeepandtill.org · 1663 → scarlethope.org ·
1667 → wsm.org · 1670 → 3adm.org

Organisation-to-domain mismatches, which are worse than a typo because the
row points at a different organisation entirely:

- **1665** "The Society of St. John the Evangelist" is filed under `ssjd.org`,
  which serves **the Society of St. John DeMatha**, a Texas prison ministry.
  Neither the row's organisation nor the Sisterhood of St John the Divine.
  The correct domain is unknown.
- **1477** "Equip (Leadership Training Network)" under `equip.org` resolves to
  the Christian Research Institute.
- **1634** "Shepherd's Center National Office" under `shepherdscenter.org`
  serves the Greater Winston-Salem centre, not a national office.
- **1639** "Sports Chaplaincy International" under `sportschaplaincy.org`
  returns nothing; the global body is at `.com`.
- **1642** `stadiacoaches.com` does not resolve.
- **1661** `thefridge.gg` and **1673** `trudiscipleship.org` do not resolve.

## A taxonomy gap

**The Utah Mission** (1666) is a single-family missionary site with one generic
giving page. It was recorded `programmes`, but it is not a fund pass-through —
it is one worker with no per-person structure because there is only one person.
The verdict vocabulary has no clean slot for a single-worker organisation.

## What this says about the promotion

The org-triage pass on 2026-09-13 promoted 283 rows into `hunt_targets`
without any surface test. On this evidence the promotion was far too generous:
roughly 5% of the cohort has the per-person surface the product needs, and a
quarter of the sample had a wrong or dead domain. The screen was the right
call, and running it before promotion rather than after would have been better
still.
