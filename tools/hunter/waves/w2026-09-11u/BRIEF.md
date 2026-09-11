# Wave w2026-09-11u — Wycliffe Bible Translators, second pass

Wave t took **302 people from 72 searches (4.2/query)** and reached only
**163 distinct person-pages**. The directory paginates past `?page=127`, so
the roster is far from spent. **The constraint here is query coverage, not
roster depth** — which is why this continuation is not the usual decay bet.

## Pattern — confirmed, do not re-verify

`wycliffe.org/partner/<slug>`. Working query shape is
**`site:wycliffe.org/partner <qualifier>`**; a bare `site:` query returns only
the paginated directory.

Nine slug shapes coexist: bare surname · surname-plural · `<surname>family` ·
both-first-names · hyphenated · initials (`LHKrause`, `jpw1990`, `TAW05`) ·
descriptive vanity (`everytribe`, `fasterandfarther`, `servantlibrarian`) ·
opaque hex ID · full UUID.

- **Never guess a slug.** Nine shapes means guessing is worthless. Rotate
  qualifiers and read what returns.
- **Surname often absent from the URL.** `/zakandlaura` is the O'Learys,
  `/hamelitz` is the Pitchers. Grade `high` and explain in `fit_reason`.
- **Opaque hex ID or UUID = `medium`, always.**

## What wave t already spent — do not re-buy it

Countries done: Nigeria, Kenya, Cameroon, Tanzania, Uganda, DRC, Ghana,
Ethiopia, Senegal, Burkina Faso, Chad, Mozambique, Mali, Ivory Coast, Mexico,
Peru, Brazil, Colombia, Guatemala, Bolivia, Ecuador, Paraguay, Russia, PNG,
Philippines, Indonesia, Thailand, Vanuatu, Solomon Islands.

Roles done: linguist, translation consultant, literacy, literacy specialist,
ethnomusicologist, Scripture engagement, Scripture use, aviation, pilot,
mechanic, nurse, IT, finance/accountant, member care, recruiter, mobilizer,
international school teacher, dorm parent, Ukarumpa, Orlando home office,
home assignment/furlough, stateside, consultant training, language development.

Places done: Ukarumpa, Madang, Aitape, Manus.

## The 149 surnames already held — use these as exclusions

Ashley Aubrey Baughman Baumunk Beachy Beamer Beekman Bennett Bitikofer Bowers
Bradford Bradshaw Buchanan Buttacavoli Campbell Carlson Carrera Carwile Choate
Clark Cordova Coulter Craig Davis Denny Dieringer DiMartino Dokken Driggers
Eberhardt Emch Federwitz Foster Fox Frank Gaddis Gallagher Gassler Goshert
Gossner Green Gregoriev Gross Guderian Hahn Hale Harmelink Harrington Hatcher
Haupt Haussler Havlicek Heath Higby Hinton Hintz Hopkins Huggins Isch Johnson
Jones Keagy Kidwell Kim Kindberg Klint Kotynski Krause Kreutz Langermann Leman
Lewis Loveland Luther Martin Mercado Miller Moe Mullins Nissley Nivens O'Leary
Oliveira Omand Park Parker Peacock Pearson Pebley Penson Peterson Pickens
Pirolo Pitcher Quakenbush Ramsey Rayl Reed Reeves Rench Richard Ring Rosendall
Roth Rothmann Russell Sacson Samuel Sasnett Savaiko Schammert Scherrer Schlote
Schrock Sheeran Shrum Simons Sjoblom Smith Spangler Stoner Tabb Tachick Thomas
Titrud Toler Trostle Turley Vinton Vogel Wagner Wahl Wakefield Walker Walton
Ward Watters Westrate Whited Williamson Winkler Winters Wood Wright Yee Yoder
Young Zielinski

Use **8–10 per query**, rotated — not forty. Past roughly a dozen negative
terms the engine silently drops the operators and re-serves excluded names; an
identical result set is the stop signal.

## Protections — unchanged and live

Wycliffe states some missionaries **withhold their details for security**.
A first-name-only or initials-only entry is a withheld surname: `needs_review`,
never emitted, and **never resolved from another source**. Children are named
on these pages constantly — emit the staff member and the support-raising
spouse, nobody else. Split couples on the **title**, never the slug.

**Retiree trap, learned the hard way in wave t.** Six records had to be pulled
at ingest. The signal is not the word "retired" — it is a **closed date range
with no current role stated**: "Indonesia Balantak 1980-2010", "SIL Director
1989-1994". A closed range *with* a current role is fine ("Burkina Faso
1995-2008, now Orlando headquarters"). Put closed-range-no-current-role people
in `needs_review`; do not emit them.

## Slices

- **u-langs** — LANGUAGE AND PEOPLE-GROUP NAMES. This is the largest untapped
  axis and no wave-t search touched it. Confirmed examples to seed from: Gbari,
  Lelemi, Dizi, Balantak, Kagayanen, Koluwawa, Urim, Leipon, Mek Kosarek,
  Supyire, Jarawara, Domung, Gumuz, Mbugwe, Zapotec, Chocoan. Then rotate
  further language-family and people-group terms of your own.
- **u-asia** — countries wave t did not touch: Nepal, India, Bangladesh,
  Myanmar, Cambodia, Vietnam, Laos, China, Japan, Korea, Taiwan, Malaysia,
  Timor-Leste, Fiji, Micronesia, Palau, Australia.
- **u-africa2** — African countries wave t did not touch: Niger, Togo, Benin,
  Liberia, Sierra Leone, Guinea, Madagascar, Zambia, Malawi, Botswana, Namibia,
  South Africa, Rwanda, Burundi, South Sudan, Eritrea, Central African Republic.
- **u-roles2** — role and function words wave t did not touch: Deaf ministry,
  sign language, oral Bible storytelling, audio recording, Scripture app,
  software developer, typesetting, publishing, font, keyboard, language survey,
  sociolinguistics, anthropology, arts, media, film, radio, printing, logistics,
  procurement, construction, facilities, guest house, hospitality, school
  principal, counselor, chaplain, human resources, donor relations, church
  relations, prayer coordinator, back-translation, exegete.

Budget: 18 searches each. `tools/hunter/prompts/enumeration.md` is
authoritative wherever this brief is silent.
