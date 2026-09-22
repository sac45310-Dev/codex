# Email extraction — SUPERSEDED, DO NOT RUN

> **This tool duplicates work that already exists and already ran, and it is
> the worse of the two implementations. Use
> `tools/hunter/harvest-contacts.mjs` in the `sac45310-Dev/donor-send`
> repository instead.**
>
> Written 2026-09-22, deprecated the same day on discovering the real one.

## What was wrong with the premise

This directory was built on the belief that 5,705 people had a stored
per-person page whose published email had never been read. That belief was
false. `harvest-contacts.mjs` ran across **the whole rostered population** on
2026-09-21 — twenty organisations with the most people lacking an address,
then the 113-organisation tail — and the results are already in the database.
The people still without an email overwhelmingly do not have one published.

Measured yields from that run, which this tool would merely have repeated:

| agency | people | emails found |
| --- | ---: | ---: |
| FOCUS | 1,770 | 568 (plus 1,196 phone) |
| Every Nation | 410 | 320 |
| Mission to the World | 537 | 282 |
| Baptist Mid-Missions | 456 | 160 |
| Africa Inland Mission | 365 | 109 |
| Baptist Bible Fellowship | 468 | **0** — one office address on all 263 pages |
| Baptist Missions to Forgotten Peoples | 207 | **0** — 115 pages fetched clean, nothing published |
| SIM Canada / Australia / UK | 469 | **0** — Australia's "addresses" were a form placeholder |
| Wycliffe, Ethnos360, RUF, ISI, CCO | — | **0** on re-measurement |

The recommendation this directory was built to serve — "run FOCUS first for
roughly 1,188 more addresses" — was wrong. FOCUS was already harvested and
yielded 568. The remaining FOCUS people have no published address.

## What the real tool does that this one does not

- **`emailNamesSomeoneElse`** — on a couple's page, the first address is not
  automatically this person's. On FOCUS, 23 of 113 would have been attributed
  to the wrong spouse.
- **`stripSharedContacts` with real thresholds** — it needs 4 sharing pages
  before the share rule fires at all, and 25 pages for the absolute rule.
  This tool's `--shared-max 3` default is below that, and on a small sample
  strips nothing, so every repeated switchboard address reads as personal.
  A two-page probe cost the other pipeline a wasted run for exactly this
  reason: RUF's 2-page probe looked like a hit, and the full 84 pages showed
  one office address on every single one.
- **Role addresses are kept and labelled, not dropped** — owner's ruling of
  2026-09-20. A shared inbox is still how you reach that person; what it needs
  is an honest `email_kind`. This tool demotes them instead.

## The one idea here worth keeping

Nothing in the other pipeline re-tests a number written in a comment. Mission
to the World sat recorded as "0, 403 on all 220 pages, Cloudflare" until
2026-09-18, when a re-run against the same people returned 203 published
addresses — the block had simply lifted. A yield of 203 was invisible for
weeks because a stale comment told every future session not to bother.

**Blocked and zero-yield agencies deserve periodic re-testing.** That is the
only thing this directory contributes, and it belongs in the real tool.

---

*Original content follows, retained for the record. Its numbers are wrong.*

| Measure | Count |
| --- | ---: |
| Approved people live as leads | 8,092 |
| Have an email | 1,901 |
| Missing an email | 6,191 |
| Missing an email, per-person URL already stored | 5,705 |

## Why the existing enrichment never covered them

`public.sales_enrich_claim` (in `supabase/migrations/20260722194210_hunting_rpcs.sql`)
selects `where sc.status = 'pending'`. Every person discussed here is
`approved`, so the queue has never been able to see them. That, not a
shortage of pages, is why only about 1,000 candidates carry `enrich_result`
at all, scattered a few each across 568 orgs.

Two options when this is picked up: widen the claim RPC to cover approved
candidates, or bypass it as this tool does. This tool bypasses it, because
the RPC also writes `scout_candidate_id` without `lead_id`, which is part of
how the contact table drifted out of joinability.

## Where the emails actually are

Emails concentrate in agency giving portals. Per-agency coverage today:

| Agency | People | With email | Coverage |
| --- | ---: | ---: | ---: |
| Every Nation | 410 | 336 | 82% |
| Cadence International | 300 | 190 | 63% |
| World Wide New Testament Baptist | 80 | 48 | 60% |
| Africa Inland Mission | 302 | 170 | 56% |
| Mission to the World | 529 | 278 | 53% |
| Baptist Mid-Missions | 456 | 227 | 50% |
| FOCUS | 1,770 | 570 | 32% |
| Baptist Bible Fellowship Intl | 454 | 0 | 0% |
| Wycliffe | 375 | 2 | 1% |
| Ethnos360 | 262 | 2 | 1% |
| Reformed University Fellowship | 222 | 2 | 1% |

**FOCUS is the best first pass.** 1,188 people have a
`focus.org/missionaries/<name>` page stored and no email, on a domain that
has already produced 570 clean addresses. The yield is proven on the exact
same page shape.

The 0-1% agencies are untested, not disproven. Every one of them has a
per-person URL stored for essentially every person. Sample ten pages from an
agency before committing a full pass, because an agency that publishes no
address at all will return an empty run.

## Running it

Two phases. The parse half needs no network, so it can be reviewed and
tested anywhere.

```sh
# 1. worklist (psql, service role)
psql "$DATABASE_URL" -v agency="focus" -f worklist.sql --csv -o focus.csv

# 2. fetch  (needs egress to the agency domain)
python3 email_extract.py fetch --worklist focus.csv --html-dir html/ \
        --rate 1.0 --resume

# 3. parse and emit SQL (no network)
python3 email_extract.py emit --worklist focus.csv --html-dir html/ \
        --out focus.sql --tag focus-2026-09-21

# 4. review, then apply
psql "$DATABASE_URL" -f focus.sql
```

`fetch` is resumable and rate-limited; `--rate 1.0` is one request per
second. At that rate FOCUS takes about 20 minutes.

Agency keys for `-v agency=` are the normalised names in the table above,
lowercased with punctuation folded to spaces, for example
`baptist bible fellowship international`. Pass `%` for every agency at once.

## Rules this tool enforces

- **Nothing is inferred.** Only addresses the page publishes are emitted.
  The CRM already holds 300 pattern-guessed addresses; more guesses would
  deepen that hole.
- **A shared address is not a personal one.** Any address appearing on more
  than `--shared-max` different people's pages (default 3) is written as
  `org` or `role`, never `direct`. Without this, one switchboard address
  would be copied onto 1,188 people and read as success.
- **Cloudflare obfuscation is decoded, not stored.** Protected pages render
  the literal `[email protected]` and hide the real address in a
  `data-cfemail` hex blob. The placeholder is rejected outright.
- **Both keys are written.** Every contact row gets `scout_candidate_id` and
  `lead_id`, and the run backfills the candidate key on rows that previously
  matched by lead alone.

## Known data problems this does not fix

- **No email in the CRM is marked verified.** All 2,880 have
  `verified = false`. Nothing here changes that; deliverability checking is a
  separate step and should happen before any send.
- **300 existing addresses are `enrich_result = 'inferred'`.** They are not
  separated from published ones in `sales.contacts`. Worth tagging before
  they are used.
- **One contact row has the domain `foucs.org`**, a typo for `focus.org`.
- **Contact-to-candidate key is populated on 2,327 of 7,302 rows.** Holdings
  checks keyed on one key alone under-report. `worklist.sql` joins on both.

## How these addresses are used (owner decision, 2026-09-21)

The organisation is approached first, and individuals are contacted only once
that organisation has given permission. Personal addresses are in scope for
two reasons: they are the only reliable unique identifier for a person inside
an agency, and they are what the permissioned outreach runs on once the agency
agrees.

Two consequences for this tool:

- **`direct` is the address class that matters.** A personal address
  identifies one person; `role` and `org` addresses identify nobody and
  cannot disambiguate two staff with the same name. The shared-address
  demotion exists to keep those classes apart, so do not raise
  `--shared-max` to inflate the `direct` count.
- **Permission is per organisation, and this tool does not track it.** The
  extractor records addresses; nothing in it marks an agency as having
  agreed to outreach. That state belongs on the organisation
  (`sales.hunt_targets`), and the send path is what must check it. Gathering
  an address is not permission to use it.

Deliverability is still an open item and separate from permission. No email
in the CRM is marked verified, so a validation pass should run before any
send regardless of which agency has agreed.
