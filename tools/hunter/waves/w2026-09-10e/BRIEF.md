# Wave w2026-09-10e — enumeration

Rendered from `tools/hunter/prompts/enumeration.md`. Six agents, 18 searches
each (108 total). Model: Haiku 4.5.

## Why these targets

The selection query ran against **corrected** coverage. Waves 09-10b/c/d had
recorded URL coverage but no query coverage — ~220 searches were invisible, so
worked ground looked cheap. 338 rows were backfilled before this wave was
planned. What that changed:

| domain | held | queries | people/query | read |
|---|---|---|---|---|
| wgm.org | 125 | 100 | 1.3 | exhausted — looked cheap before the backfill |
| fmwm.org | 38 | 27 | 1.4 | exhausted |
| onemissionsociety.org | 213 | 49 | 4.3 | declining (last wave gave 33) |
| ethnos360.org | 230 | 20 | **11.5** | best ratio of any worked domain |
| bimi.org | 132 | 15 | 8.8 | ID range 21–1725, ~7.6% mined |

Without the backfill this wave would have re-bought WGM and OMS.

The never-queried domains already in `scout_candidates` were checked and are
**not** seams: 36 of 37 have zero Tier A — they are board/about-page rows, not
support-raised staff. The untouched ground is in `hunt_targets`: agencies with
a website and no `site:` coverage at all.

## Verification before dispatch (10 searches, orchestrator-run)

Confirmed:

| target | pattern | depth signal |
|---|---|---|
| **CMML** | `cmml.us/m/<id>`, giving at `cmml.us/donate/missionary/<id>` | observed IDs 42–1339; Prayer Handbook lists 750+ commended workers |
| **MWBM** | `mwbm.org/hp_wordpress/wp-content/uploads/YYYY/MM/Surname-Firstname-Month-Year.pdf` | full 2024–2026 prayer-letter archive; **name is in the filename** |
| **IBFI** | `ibfi.us/missionaries/missionaries-by-region/<region>/<slug>` and `ibfi.us/images/files/Missionary Prayer Letters/<Full Name>/` | regional directory + per-person letter folders |
| **Family Missions Company** | `familymissionscompany.com/project/<slug>` | lay Catholic families, fully support-raised |

Rejected:

- **Frontiers USA** — all giving flows to a pooled "Mission Fund"; no
  per-person pages, and Muslim-world workers are deliberately anonymized.
  Going to `hunt_negatives`.
- **Eastern Mennonite Missions** — `emm.org/workers/` is one directory page;
  no per-worker slug surfaced in two searches. Not dispatched.
- **IMB, Alliance Missions, Christian Aid Mission** — not support-raised
  (Cooperative Program / Great Commission Fund / indigenous-funded). No Tier A.

Verification cost 10 searches and killed three targets that would have cost
~54. This is the fourth wave running where it paid for itself.

## Assignments

| agent | target | slice |
|---|---|---|
| `cmml-low` | CMML | profile IDs m/1–m/650 |
| `cmml-high` | CMML | profile IDs m/651–m/1400 |
| `mwbm` | Macedonia World Baptist Missions | 2024–2026 prayer-letter PDF archive |
| `ibfi` | Independent Baptist Fellowship Intl | missionaries-by-region + letter folders |
| `fmc` | Family Missions Company | `/project/` missionary pages |
| `eth-deep` | Ethnos360 | qualifiers NOT already spent (see below) |

`eth-deep` must avoid the 20 qualifiers already bought: Brazil, Bolivia,
Colombia, Mexico, Panama, Paraguay, Senegal, Guinea, Ivory Coast, Roatan,
Papua New Guinea, Philippines, Indonesia, Borneo/Kalimantan, Tanzania, Canada
arctic, aviation, Bible institute, Sanford HQ, home office. Open ground:
Thailand, Malaysia, Venezuela, Ecuador, Peru, Guyana, Suriname, Mozambique,
Chad, Cameroon, Ghana, Liberia, Spain, Eurasia/Mongolia, and role qualifiers
(medical, nurse, MK school teacher, literacy consultant, finance, IT).

## Per-target anonymization signals

Each agency labels withheld workers differently. These go to `needs_review`,
never to `people[]`:

- **CMML** — "for security or other reasons, some missionaries keep their
  information private"; profiles titled `Missionary #NNN` with no name in the
  body are withheld, not merely terse.
- **MWBM** — sensitive-country letters are not posted; the archive says to
  contact the home office. A letter referenced but absent is a signal, not a
  target.
- **IBFI** — regional pages that list a slug but no full name.
- **FMC** — families serving in restricted countries listed by first name only.

## Note on CMML titles

CMML page titles read `Missionary #799`, not the person's name — the name is in
the body and does surface in search snippets ("John and Eleanor Sims", "The
Smiths"). Per the numeric-ID rule this makes the URL opaque: **CMML records are
`medium` confidence unless the snippet ties the named person to the ID**, and
`fit_reason` must say so. Do not emit a record whose name came from the title
alone — the title has no name in it.
