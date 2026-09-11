# Wave w2026-09-11t — Wycliffe Bible Translators

Target: **Wycliffe Bible Translators USA** (`wycliffe.org`), hunt_target id 3,
priority 88. Reopened 2026-09-11 after being wrongly recorded as
`platform_not_person` in w2026-09-10n.

## The pattern is confirmed. Do not go looking for it.

Per-person giving pages live at **`wycliffe.org/partner/<slug>`**. Verified
examples, each returned by search with its page title:

| URL | title |
|---|---|
| `/partner/moefamily` | Jonathan & Jenny Moe |
| `/partner/zakandlaura` | Zak & Laura O'Leary |
| `/partner/devinandcharity` | Devin & Charity Schlote |
| `/partner/fix` | Jonathan and Jenny Fix |
| `/partner/Gossners` | Jan and Debbie Gossner |
| `/partner/CEFDA0` | David & Fran Wakefield |
| `/partner/A18F31` | Brad and Toni Guderian |
| `/partner/bryan-lori-jones` | Bryan and Lori Jones |
| `/partner/esthermorrow` | Esther Morrow |
| `/partner/garrettandleahharrison` | Garrett and Leah Harrison |

**The working query shape is `site:wycliffe.org/partner <qualifier>`.** That is
how every example above was found. A bare `site:wycliffe.org/partner` returns
only the directory; you must add a country, language or role qualifier.

## This agency has the most varied slugs in the project — read this twice

At least nine shapes are in use on the same site:
`<surname>` · `<surname>s` · `<surname>family` · `<first>and<first>` ·
`<first><first><surname>` · `<first>-<first>-<surname>` · `<firstsurname>` ·
initials-and-fragments (`DonWendyTin`, `dstroyer`) · **opaque hex IDs**
(`CEFDA0`, `A18F31`).

Consequences, all of which are graded, not optional:

- **Slug guessing is worthless here.** Do not spend a single search guessing a
  URL from a name. Find pages via qualifier rotation and read what comes back.
- **The surname is often NOT in the slug.** `/partner/zakandlaura` is the
  O'Learys. That is the inverse of the usual case. Grade it `high` — the slug
  is that couple's own vanity URL and the title names them in full — and say
  so in `fit_reason`.
- **An opaque hex ID is `medium`, always.** `/partner/CEFDA0` is the Wakefields
  only because the title says so. The URL does not tie the page to the name.
  This is the rule that had to be applied to 128 BIMI, 27 GEM and 5 InterVarsity
  records across earlier waves. Do not grade these `high`.
- Judge **per record, not per domain**. Both shapes sit on one site.

## Protections — Wycliffe states that some missionaries withhold their details

This is the agency's own published position, so treat it as live, not
hypothetical.

- **A first-name-only entry is a withheld surname.** The directory carries
  people like "Paula, serving in Papua New Guinea on the Urim language
  project". Those go to `needs_review`. Never emit them, and **never resolve a
  withheld surname from another source** — you would be undoing a protection
  the agency put there deliberately.
- Same for initials-only entries and anything under a security or sensitive
  category.
- **Children are not missionaries.** These profiles routinely name the kids
  ("they have a six year old daughter and three year old son"). Emit the
  staff member and the support-raising spouse. Nobody else on the page.
- Split couples on the **TITLE**, never the slug. `/partner/moefamily` is two
  people, Jonathan Moe and Jenny Moe. Couples are the norm at this agency, so
  this is where most of the volume is.
- If the slug names two people and the title names one, emit the one and put
  the other in `needs_review` — an agency keeps the URL and rewrites the page
  when a spouse dies.

## Citation rule specific to this site

`wycliffe.org/partner/missionaries?page=N` is a **paginated query-string
directory**, not a page about a person. Search will return it constantly.
Citing it is the search-results-URL error that produced twelve unusable
records in w2026-09-10e. If a person appears only in the directory and you
cannot find their `/partner/<slug>` page, grade them `staff_directory` /
`medium` and cite the directory page — or skip them. Never cite `?page=N` as a
`personal_page`.

## Slices — non-overlapping by country, so stay inside yours

- **t-png** — Papua New Guinea (the largest single field), plus Pacific and
  Asia: Philippines, Indonesia, Thailand, Vanuatu, Solomon Islands.
- **t-africa** — Nigeria, Kenya, Cameroon, Chad, Tanzania, Uganda, DRC, Ghana,
  Senegal, Ethiopia, Burkina Faso.
- **t-americas-europe** — Mexico, Peru, Brazil, Colombia, Guatemala, Bolivia,
  plus Europe/Eurasia.
- **t-roles** — no country qualifiers at all. Rotate ROLES and locations of
  service in the US: linguist, translation consultant, literacy specialist,
  ethnomusicologist, Scripture engagement, aviation, IT, finance, member care,
  recruiter, Ukarumpa, Orlando home office, teacher at an international school.

A note on why the slices are drawn this way: the w2026-09-11s Reach Beyond wave
split two agents geographically and **38 of 56 names collided**, because the
region was in neither the URL nor the title. Here the snippets do carry country
names, which is why geography should work — but if you find yourself returning
names your slice does not cover, say so in `coverage` rather than quietly
keeping them.

## Support-raising is universal here

Wycliffe missionaries raise personal support, including home-office staff in
Orlando. Do **not** tier someone down because their role is IT, finance,
teaching or administration. Tier on whether the person raises personal support,
not on job function.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
