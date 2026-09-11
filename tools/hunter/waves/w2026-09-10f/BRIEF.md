# Wave w2026-09-10f — Ethnos360 role qualifiers

Rendered from `tools/hunter/prompts/enumeration.md`. Four agents, 18 searches
each (72). Model: Haiku 4.5. Single target, sliced by **role family**.

## Why role-only, and why Ethnos360 again

Ethnos360 returned 4.7 people/query in w2026-09-10e — the best rate of any
target in that wave and roughly four times CMML's. We hold 345 (333 Tier A).

Geography is nearly spent: 24 country qualifiers have been bought across five
waves (Brazil, Bolivia, Colombia, Mexico, Panama, Paraguay, Senegal, Guinea,
Ivory Coast, Roatan, PNG, Philippines, Indonesia, Borneo, Tanzania, Canada
arctic, Thailand, Malaysia, Venezuela, Ecuador, Peru, Mozambique, Chad,
Liberia — plus Guyana, Suriname, Cameroon and Ghana which returned nobody).

**Role is the axis nobody has worked.** Only 13 role qualifiers have ever been
bought: aviation, pilot, mechanic, Bible institute, Bible translation,
literacy, medical, nurse, dentist, finance, IT, leadership, home office. Of
those, role searches in the last wave produced three IT couples, a nurse, a
dentist and a finance worker — the axis pays, it just has not been mined.

Our own role distribution shows why there is room: of 345 held Ethnos360
records, 286 are logged simply as "Missionary". The specialists are there; we
have not asked for them by name.

## Do NOT re-buy these

Any qualifier listed above. Also do not lean on `-surname` exclusions: the
technique is measured to fail above ~15 held records per domain and we hold
345. Rotate a fresh qualifier instead — that is what produced the 4.7 rate.

## Assignments

| agent | role family | slice |
|---|---|---|
| `eth-education` | schools and childcare | MK school teacher, dorm parent, principal, tutor, childcare, Numonohi Christian Academy, education, houseparent |
| `eth-technical` | trades, logistics, media | construction, builder, maintenance, electrician, engineer, water, agriculture, logistics, shipping, procurement, radio, Scripture recording, audio, video, photography, communications |
| `eth-linguistic` | language work | linguist, linguistics, phonetics, orthography, translation consultant, literacy **specialist**, language consultant, Scripture use, culture acquisition, discipleship materials |
| `eth-care-admin` | people and office | member care, counselor, counseling, debriefing, guest home, hospitality, HR, personnel, administrator, bookkeeper, accountant, mobilizer, recruiter, church relations, candidate coach |

Note for `eth-linguistic`: bare "literacy" was tried and came back **offtopic**
— it surfaces the Literacy Starter software product, not people. Qualify it
("literacy specialist", "literacy worker") or skip it.

## Surfaces

Both are confirmed and both carry the surname in the slug, so records are
`high` when the title corroborates:

- `ethnos360.org/missionaries/<name-slug>`
- `blogs.ethnos360.org/<name-slug>`

A third, `homes.ethnos360.org/story/<name-slug>`, appeared last wave. It is the
**retirement homes** site — treat anyone found there as `needs_review` rather
than Tier A, since a resident may be retired rather than actively raising
support. Two couples were loaded as Tier A from it in w2026-09-10e and are
flagged for review.

## Tiering

Field missionaries raise personal support: **Tier A**. Home-office,
mobilization and training-centre staff are **Tier B** unless the page shows a
personal support ask. Specialist field roles (nurse, teacher, mechanic serving
on a field team) are Tier A — they raise support like any other field worker.

## Anonymization

Ethnos360 works tribal and restricted areas. Any profile with an initials-only
slug, a withheld surname, or a sensitive-region label goes to `needs_review`,
never to `people[]`.
