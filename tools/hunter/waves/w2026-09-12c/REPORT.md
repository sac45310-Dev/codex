# Wave w2026-09-12c — ISI second pass

**23 net-new from 65 searches — 0.35 per query.** Retirement line is 1.3–1.4.
`roster_status` set to **exhausted**. ISI closes at **170 held**.

| agent | axis | searches | emitted | reported /q |
|---|---|---|---|---|
| isi2-a | role phrases, exhaustive | 23 | 84 | 3.65 |
| isi2-b | couple-slug enumeration | 18 | 41 | 2.28 |
| isi2-c | university names | 24 | 48 | 2.0 |

173 raw → 121 distinct → 116 after protections → **23 net-new against the CRM.**

## The denominator gap at its widest

Every agent cleared the retirement line against its own running set. The wave
did not clear it at all. **93 of 116 clean records were people wave b already
found.** Agent A said so itself before the merge — "this is *not* the wave
metric, recompute after the merge" — which is the template rule from wave b
working exactly as intended, one wave after it was written.

This is the third wave in a row where per-agent yield and wave yield told
opposite stories. It should now be treated as the default expectation, not a
surprise: **when agents share a target, their individual rates are inflated by
however much their axes overlap, and role-shaped axes overlap almost totally.**

## The axis questions the wave was built to answer

**Couple-slug shapes — plural surname wins, ~3×.**

| shape | pages | people |
|---|---|---|
| plural surname (`/kestles/`, `/strouds/`) | 13 | 26 |
| bare singular surname (`/innis/`, `/downs/`) | 4 | 8 |
| full two-name (`/hon-and-carol-lam/`) | 3 | 6 |

The bare-singular form **cannot be reached by cold surname rotation** — it only
surfaced when a query anchored on slugs already known, and cold rotation against
it came back empty four times running.

**University names lost to role phrases** — not on peak but on reliability.
Berkeley returned 16 and Purdue 14, essentially matching the role axis best of
17. But **15 of 24 queries returned nothing**, because the literal token `team`
in `site:internationalstudents.org/team` collides with "*University* football
team" on Wikipedia. That is wave b's dead-state failure arriving by a different
route, and it means the axis cannot be walked systematically. Agent C also found
that when a university token does *not* collide it is not filtering at all —
Purdue, Emory and Stanford returned the identical fallback set. The university
word behaves as a weak random sampler of the namespace.

**Two mechanical facts worth keeping.** `Georgia Tech` and `Ohio State` degrade
to their state token and return ISI's own landing pages, so any state-containing
university name inherits the dead-state failure. And **negative search operators
are ignored by this backend entirely** — `-football -basketball` changed nothing.
That is independent of the exclusion-list ceiling and worse: the terms are not
merely limited, they do nothing.

**Role phrases: four carry the axis.** Area Director, City Director, Campus
Staff and Campus Director produced 50 of agent A's 84. Narrower titles resolve
to people the broad phrases already returned. Support-raising language
(`"ministry partners"`, `"prayer and financial support"`) is dead — ISI bios do
not use that vocabulary.

## A defect in wave b, found by this wave, in records already approved

Wave b's rule 7 said a couple page yields two records. It does — but wave b
then **copied the page's single role title onto both spouses**, and the spouse
may hold a different role.

Agent A read eight such pages again and found **four of the eight spouses are
labelled Ministry Representative** — ISI's separate track, which rule 6 bars.
Kim Notehelfer, Lia Dunne, Christy Lynn Flynn and Linda Berger had all been
loaded as Campus Staff and **had just been bulk-approved**. All four are back to
`pending` with the reason on the record.

That is a 50% error rate on the sample, but the sample is biased — agent A
looked at pages whose snippets exposed a difference. The honest response is not
to extrapolate: **the other 90 records sitting on shared-role couple pages now
carry `role_inherited: true`** and a note saying the role is unverified. Status
unchanged; confirm before outreach.

Agent C separately caught **Craig Mosher**, loaded and approved by wave b as
Campus Staff, whose page carries a volunteer label and closed 1990–1996 and
2003–06 ranges with no current role. Returned to `pending`.

Reversal for all of it: `sales.isi_role_fix_20260912`.

## Holds bound across waves, three times, unprompted

Agent B re-held Simon and Becky Zeigler on wave b's existing hold. Agent C did
the same and declined to re-emit them. Agent A found the Zeigler/Carroll pages
show current roles, emitted them, and **flagged the prior-wave conflict in
`needs_review` rather than overturning the hold by its own count** — which is
precisely right. Samuel and Joanne Carroll were dropped from this ingest on
wave b's hold.

New holds this wave: Ginger Ehmann (Ministry Representative), Craig Mosher,
Jordan Lassiter and Emily Tidd and Wendy Herring (named in body, not title),
Rebekah Miller (archive byline, no citable page).

## One deliberate rule departure, disclosed

Agent C hit three consecutive empties across three different shapes at queries
2–4 — the literal stop condition — and kept going, on the grounds that query 1
had returned 8 person-pages on the same shape query 4 failed on, so the surface
was demonstrably not exhausted and the university token was the variable. That
call produced 34 of its 48 records. It flagged the departure rather than hiding
it. The judgement was right, and it suggests the corrected stop rule still needs
a carve-out for *"a query of this shape has already succeeded in this run."*

## Non-people under `/team/`

`denver_auraria`, `isi-memorial-gift`, and a new one this wave,
`bridgeport-intl-campus-church`. The path remains necessary and never sufficient.
