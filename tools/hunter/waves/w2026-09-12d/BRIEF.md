# Wave w2026-09-12d — ISI university axis, re-run with `blocked_domains`

## Why

Wave c's agent C lost **15 of 24 queries** on the university-name axis because
`site:internationalstudents.org/team <University>` collides with
"*University* football team" on Wikipedia. It concluded the axis was unworkable,
and ISI was marked `exhausted` at 170 partly on that finding.

`SEARCH-OPERATORS.md` (2026-09-12) established that `blocked_domains` works in
every test, and that no wave has ever used it. The conclusion above therefore
rests on a broken measurement. This wave re-runs the same axis with the fix.

**One agent, 24 searches.** This is a measurement, not a harvest. Its job is to
answer two questions honestly:

1. Does `blocked_domains: ["en.wikipedia.org"]` make the university axis work?
2. Are there people left at ISI that the collision hid?

## The setup

Every query carries `blocked_domains: ["en.wikipedia.org"]`. If off-domain
noise from other hosts appears, add those hosts too and say so.

Rotate the same university list wave c used, so the comparison is clean:
Purdue, Ohio State, Michigan State, Penn State, Texas A&M, Georgia Tech,
Virginia Tech, NC State, Iowa State, Kansas State, Arizona State, Oregon State,
UCLA, Berkeley, Duke, Emory, Vanderbilt, Rice, Cornell, Rutgers, UMass, UConn,
Syracuse, Buffalo.

Wave c also found that state-containing names (`Georgia Tech`, `Ohio State`)
degrade to the state token and return ISI's own landing pages. Test whether
`blocked_domains` changes that; it probably does not, since those pages are
on-domain.

## Rules — all unconditional

1. Emit only `internationalstudents.org/team/<slug>` pages whose title is a
   person's name. `/team/denver_auraria/`, `/team/isi-memorial-gift/` and
   `/team/bridgeport-intl-campus-church/` are not people.
2. Every record is `high` confidence; a slug without the surname makes it `medium`.
3. `evidence_basis` is `personal_page`; `fit_score` 9 for `high`, 7 for `medium`;
   Tier A.
4. Volunteers and Ministry Representatives go to `needs_review`, not emitted.
5. A couple page yields two records, names from the **title**, and **the role
   belongs only to the spouse the page names in it** — never inherit a role
   across a couple. Leave `role` null on a spouse whose role the page does not
   state separately.
6. Emit a second person only when the title names them.
7. Initials-only, first-name-only or codename titles go to `needs_review`,
   never emitted, never resolved from another source.
8. A closed date range with no current role goes to `needs_review`.
9. Never record or infer any individual's demographic or identity attributes.
10. **Read the URL list, not the summary.** The backend's prose summary has
    asserted exclusions were applied when they were not, and that they were
    unsupported when they worked. It is not evidence.

Existing holds bind: the Zeiglers, the Millses, the Carrolls, Jill Mitchell,
Ginger Ehmann, Craig Mosher, and the four Ministry Representatives from wave c
(Kim Notehelfer, Lia Dunne, Christy Lynn Flynn, Linda Berger). Do not re-emit.

No surname exclusion lists. Emit everything that qualifies; the orchestrator
dedupes at ingest against 6,874 person records.

## Stop rule

Three consecutive empties on three different shapes — except when a query of
one of those shapes already succeeded earlier in this run.

## Report

For each query: the university, whether Wikipedia noise was present in the
result list (it should not be), how many `/team/` person pages came back, and
how many were new to your running set. Then: `new / 24`, and a direct
comparison to wave c's 9-of-24-productive on the same list.
