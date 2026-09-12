# Wave w2026-09-11w — Mission to the World (MTW)

`mtw.org`, the global sending agency of the Presbyterian Church in America.
**Fresh target — zero people held.** The org states **636 missionaries serving
one year or longer across 100 countries**, plus 1,101 short-term.

## Pattern — confirmed by orchestrator probe, do not re-verify

**`mtw.org/missionaries/details/<surname>-<first>/`**

Verified: `/missionaries/details/meadows-amanda/` (Amanda Meadows),
`/missionaries/details/crews-virginia` (Virginia Crews).

**The slug is SURNAME-FIRST**, the same shape as InterAct Ministries. Do not
read `meadows-amanda` as a person named Meadows Amanda. Titles render as the
plain name ("Amanda Meadows").

Index at `mtw.org/missionaries/` with a paginated search reaching at least
`?page=14`. There is also `mtw.org/missionaries/itinerating-missionaries/?show=all`
— **itinerating missionaries are people currently raising support**, which is
the most on-profile group at the agency. Work that path deliberately.

Working query shape: **`site:mtw.org/missionaries <qualifier>`**.

## Tier

MTW missionaries raise personal support — the site talks explicitly about
praying for missionaries "raising support so they can serve internationally".
Tier A. Do not tier down on job function: administrators, teachers, MK
schooling staff and business-as-mission workers raise support like everyone
else.

## Protections — one is stated by the agency itself

**MTW says: "If interested in supporting missionaries who serve in secure
locations, email for more information."** That is an explicit sensitive-worker
population. Consequences:

- Any entry published without a surname, with initials only, or flagged as a
  secure/creative-access location goes to **`needs_review`** — never emitted,
  and **never resolved from another source**.
- If a country in your slice is one where workers are commonly anonymized,
  expect gaps and record them in `coverage` rather than filling them by
  inference.

Standard rules also apply and are not optional here:

- **Split couples on the TITLE, never the slug.** If the slug names two people
  and the title names one, emit the one and put the other in `needs_review`.
- **Children are not missionaries.** These profiles name them; emit the staff
  member and the support-raising spouse only.
- **Do not cite `mtw.org/missionaries?page=N`** or the map page as a
  `personal_page` — those are paginated directories. If a person appears only
  there, grade `staff_directory` / `medium`, or skip.
- Never record or infer anyone's demographic or identity attributes.

## Slices — non-overlapping

- **w-itinerating** — work `mtw.org/missionaries/itinerating-missionaries/`
  hard, plus "raising support", "partnership development", "preparing to
  serve", "newly appointed". This is the highest-value slice: people actively
  building a donor base.
- **w-latam-europe** — Mexico, Peru, Brazil, Chile, Bolivia, Ecuador, Honduras,
  Costa Rica, Dominican Republic; plus Spain, Portugal, France, Germany, Italy,
  Czech, Poland, Ukraine, Romania, Bulgaria, Ireland, UK.
- **w-africa-asia** — Kenya, Uganda, Ethiopia, South Africa, Malawi, Zambia,
  Ghana, Senegal; plus Japan, Thailand, Cambodia, Philippines, Indonesia,
  Taiwan, Australia. Be alert for secure-location gaps here.
- **w-roles** — no country qualifiers. Rotate: church planter, campus ministry,
  theological education, seminary, teacher, MK school, business as mission,
  mercy ministry, medical, counseling, youth, music, administration, team
  leader, regional director, diaconal, refugee ministry.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
