# Wave w2026-09-12a — SIL International

## Verify-then-dispatch, both questions

**Do we already hold these people?** Keyed on org name and the `hunt_target_id`
FK, per the 2026-09-12 audit rule, with the domain read out of
`hunt_targets.website` rather than typed from memory:

- `hunt_target_id = 487`: **1 record**
- `meta->>'target_org' ilike '%SIL%'`: **0 records**
- `source_url ilike '%sil.org%'`: **1 record**
- not in `hunt_negatives`; no `hunt_coverage` rows

Genuinely unworked. This is the check wave z got wrong.

**Does a per-person surface exist?** Yes, and it is mixed. Six probe searches
found the giving host is **`give.sil.org`, not `sil.org`** — the target row is
being corrected.

| shape | what it is |
|---|---|
| `give.sil.org/give/<numeric-id>`, title **"Donate to `<Name>` Support"** | **a person** |
| `give.sil.org/give/<numeric-id>`, any other title | a fund or programme |
| `give.sil.org/campaign/<id>/donate` | never a person |
| `give.sil.org/<vanity-slug>` (`/paratext`, `/LangTech`, `/archives`) | never a person |

Confirmed people: `give/484678` "Donate to Oliver Dixon Support",
`give/500598` "Donate to Saul Delgado Support Page".

## The risk this wave is testing

Six probe searches surfaced **two** people. Everything else was a campaign, a
regional fund or a software project. Two readings:

1. Member support pages exist but are largely unindexed.
2. **Most SIL members raise support through their sending organisation, not
   through SIL.** Every SIL person already in the database is held under
   *Wycliffe*: Esther Morrow is "Cartographer — SIL Americas" at
   `wycliffe.org/partner/esthermorrow`; Jaime Ayala is "Director, SIL Americas
   South" on a Wycliffe bio; Emily Roth is filed "Wycliffe/SIL".

If (2) holds, SIL is not a new agency — it is a **second view of the Wycliffe
roster we already worked twice**. Report new-people-per-query honestly and stop
early if it is at or under the 1.3–1.4 retirement line.

Do **not** apply a surname exclusion list. The exclusion-operator ceiling is
~10–12 terms and exclusion lists have hidden real people before. Emit everything
that qualifies; the orchestrator dedupes at ingest against all 6,691 person
records already held.

## Rules — all unconditional

Wave z produced zero violations across 227 records on unconditional rules; wave u
dropped conditional ones under load. These are written to be weighed by nobody.

1. **Emit a record only when the page title reads "Donate to `<Firstname>
   <Lastname>` Support" or "… Support Page".** A title naming a programme,
   a place, a language, a tool or a fund is not a person. No exceptions.
2. **Any URL containing `/campaign/` is not a person.** No exceptions.
3. **Every record from this agency is `medium` confidence.** The slug is a numeric
   ID and never ties to the name, so nothing here earns `high`. No exceptions.
4. **`evidence_basis` is `personal_page` for every emitted record.** The page is
   that person's own support page. No exceptions.
5. **`fit_score` is 7 for every emitted record** (Tier A, medium). No exceptions.
6. Any title giving initials only, a first name only, or a codename goes to
   `needs_review` and is **never** emitted and **never** resolved from another
   source. No exceptions.
7. Any title or snippet stating a closed date range with no current role goes to
   `needs_review` as a suspected retiree. A closed range *with* a current role is
   fine. No exceptions.
8. **Never record or infer any individual's demographic or identity attributes.**
   No exceptions.

## Axes — 24 queries each, 72 total

Do not use `site:sil.org`; the people are on `give.sil.org`.

- **agent A — Africa and Asia.** Country and region names against
  `"give.sil.org" "Donate to" "Support"`. Africa is SIL's largest region (545
  communities, 64 years).
- **agent B — Americas, Eurasia, Pacific.** Same shape, different geography.
  Wave t showed geography splits cleanly when the region is in the indexed text.
- **agent C — roles and disciplines.** translator, linguist, literacy specialist,
  Scripture engagement, language technology, consultant, ethnomusicologist,
  language surveyor, translation consultant, academic. Wave u found the
  language-and-people-group axis was the *worst* for Wycliffe; roles are the
  untested one here.

Report `new_people_found / queries_run` per agent. Search titles, URLs and
snippets only — WebFetch is EGRESS_BLOCKED.
