# Wave w2026-09-10m — FOCUS via third-party campus rosters

**Dispatched** 2026-09-10. Four agents, 72 searches, **71 net new people**.
**Rate: 0.99 per query — below the 1.3–1.4 retirement line. FOCUS is retired
as a search target.**

## Result

| agent | region | searches | raw | rate (raw) |
|---|---|---:|---:|---:|
| focus-newman-south | South / Southeast | 18 | 38 | 2.1 |
| focus-newman-mw | Midwest / Plains | 18 | 28 | 1.6 |
| focus-newman-east | Northeast / Mid-Atlantic | 18 | 17 | 0.94 |
| focus-newman-west | West / international | 18 | 9 | 0.50 |
| **total** | | **72** | **92 raw → 71 net** | **0.99** |

21 of the 92 were people we already held. 32 records carry a
`personal_page` citation, 39 a weaker `staff_directory` one.

FOCUS ends at **522 of ~981 — 53%**. Database total 4,203.

## The call I got wrong, and when I caught it

My wave-l report recommended a third pass on the remaining focus.org
campuses as "the highest-confidence work available." **Four pre-dispatch
probes killed that before an agent ran:**

| probe | focus.org person pages | new to us |
|---|---:|---:|
| Saint Louis U / UT Dallas / Houston / Sacramento State | 2 | 0 |
| Akron / Youngstown / John Carroll / Cleveland State / Case Western | 0 | 0 |
| surnames: Nguyen / Kowalski / Hoffman / Sullivan / Fitzgerald | 3 | **1** |
| "first year missionary 2026" | 0 | 0 |

Every wave-l probe returned ten new out of ten. The surname axis — the one
axis never tried — came in at roughly 1 per query, already below retirement.

So the wave was re-pointed at third-party campus rosters, which had never
been searched. That axis is real: it produced 71 people where focus.org
produced 1. It is still not enough.

## Why FOCUS is capped rather than exhausted

~460 FOCUS missionaries exist that we do not hold. They are not hidden —
they are **on pages search cannot read**. Confirmed live, correctly titled
FOCUS roster pages that yield zero names in a snippet because they render
teams as images or JS blocks:

`bulldogcatholic.org` · `huskercatholic.com` · `newmanec.com` ·
`iowacatholic.org` · `staparish.net` · `stisidores.com` ·
`catholictigers.org` · `catholicnoles.org` · `ugacatholic.org` ·
`aucatholic.org` · `txstatecatholic.org` · `utcatholic.org` ·
`baylorcatholic.org` · `gmuccm.org` · `volcatholic.org` · `saclemson.org` ·
`asucatholic.org` · `catholicjacks.org` · `calnewman.org` · `uonewman.org`

All are recorded as `url` coverage with `no_people`. **These are page-fetch
targets, not search targets.** No amount of query rotation will open them,
and WebFetch is blocked in this environment. That is the whole story of the
missing 460.

## Two findings worth keeping

**An `@focus.org` email on a roster is the discriminator.** Where a campus
page publishes addresses, FOCUS missionaries separate cleanly from diocesan
chaplains, lay ministers and student leaders with no guessing. It also
resolves nicknames safely — "Lily Bernero"/`lillian.bernero@`, "Dan
Tully"/`daniel.tully@`, "Maddy Fischahs"/`madison.fischahs@` — the address
supplies the legal first name without inference. Where a page had no
emails, it was usually unusable.

**Harvest-then-name-lookup reaches people campus-name search cannot.** Two
batched stage-2 queries covering sixteen Northeast names upgraded six to
personal pages — people who were *not* findable by campus-name search on
focus.org. That partly inverts wave l's conclusion: the Northeast people
are in the focus.org index; the campus metadata is not.

Best single surface of the wave: the **Pittsburgh Oratory**
(`thepittsburghoratory.org/ourpeople`), publishing two rostered FOCUS teams
— Pitt and Carnegie Mellon — with directors marked and full
`firstname.lastname@focus.org` addresses. It outproduced every New England
query combined.

**Austria broke open in German**, exactly as wave l predicted. English
returns nothing; `"FOCUS Missionare" Katholische Hochschulgemeinde`
immediately surfaced KHG Wien with a dedicated roster page and confirmed
teams at Graz. Germany (Passau, Cologne) is unclaimed ground no slice
covered.

## The fabrication hazard, caught

A search synthesis handed the Midwest agent **"Colton Garity"** — a surname
welded onto the first-name-only bulldogCatholic roster, complete with a
degree and graduation year, and contradicting that same page's attribution
of the identical degree to a different first name. The agent logged it as
a do-not-ingest instead of emitting it. Two other first-name-only teammate
lists were dropped the same way, and an infant named on a team list was
excluded under the children rule.

This is the exact failure the brief predicted for this axis, and it arrived
dressed as a complete, confident record.

## Dedup

The wave's dedup risk was different from wave l's: a roster citation for
someone already held via their personal page is a pure duplicate, not a new
person. A normalized-name guard in the insert blocked 18 of those. Three
more — Chris/Christopher Guttuso, Nic/Nik Ruby, Lily-Kate Prichard/Pritchard
— are spelling variants the guard could not catch; they were dropped during
transcription rather than by a check, so **the outcome was right and the
mechanism was luck.** A near-duplicate review pass afterwards caught one
survivor, Daniel Tully vs the held Dan Tully, which was deleted. It also
correctly left alone five same-surname pairs that are real distinct people
or spouses.

One record was **upgraded rather than duplicated**: Nicholas Fornarotto was
banked from a probe on a roster citation, and the Midwest agent found his
own focus.org page — the existing row was rewritten to the stronger
citation.

## Weaker citations, honestly labelled

39 of 71 records cite a roster, not a giving page. Tier A still holds —
FOCUS states all missionaries raise 100% of their own support — so this is
thinner evidence, not a worse prospect. Roster staleness is recorded
per-record: SMU claims 2020-21, Arkansas Catholic 2022, JMU 2024-25, the
Black Hills State cohort is the campus launch year, and the rest are
current. One record (Mike Wollen, Temple) rests on a campus-ministry video
rather than a roster and carries no year at all; it is the weakest citation
in the wave and is labelled as such.

## Coverage recorded

72 queries + 57 URLs = 129 rows. The URL rows are the valuable half: they
are a map of which campus-ministry sites are live-but-unreadable, so the
next wave does not re-buy them.

Agents again emitted coverage kinds the check constraint does not allow
(`site`, `page`). Where the value was a URL these were remapped to `url`
rather than discarded — 57 rows that would otherwise have been lost. The
template should name the two legal kinds explicitly.

## Verdict

**Retire FOCUS.** 522 held, 53% of the pool, priority dropped to 55. Three
waves took it from 0 to 164 to 451 to 522, and the marginal wave has now
fallen from 5.5 to 0.99 new people per query.

The next wave should go to an **untouched agency**. That has been the
reliably productive move at every decision point in this project: every
untouched agency with a verified per-person surface has returned 2.7–5.5
per query, while every continuation has decayed. FOCUS's remaining 460 are
worth revisiting only if page fetching becomes available — at which point
the twenty roster URLs above, and Seton Hall's unnamed ~12, are a ready
work list.
