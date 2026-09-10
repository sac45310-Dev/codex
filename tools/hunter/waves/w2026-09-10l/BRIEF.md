# Wave w2026-09-10l — FOCUS, second pass

**Target:** FOCUS (Fellowship of Catholic University Students), `focus.org`
**Pattern (confirmed, do not re-derive):** `focus.org/missionaries/<slug>`
**Agents:** 5 · **Budget:** 18 searches each · **Wave dir:** `tools/hunter/waves/w2026-09-10l/`

Every FOCUS missionary raises 100% of their own salary. The org states this
itself. **Every record in this wave is Tier A / `personal_page`.** Role is not
a tier signal here — Team Director, Coach, Program Director, Sr. Manager and
Parish Missionary all sit on the same per-person giving page.

## Why we are back

Wave k took 164 people in 34 searches. FOCUS has **~981 missionaries at 234
locations, 211 of them campuses**, and is growing toward ~1,300. We hold
**17%**. Wave k mined one axis — common first names — nearly flat. Three
axes are essentially untouched, and a pre-dispatch probe of each returned
**ten results out of ten that we do not hold.**

## The couple sub-surface — read this even if it is not your slice

FOCUS family pages carry **two support-raising adults on one URL**, and wave k
harvested many of them only halfway. Two shapes:

1. **The slug names both** — `david-and-catherine-wentworth`,
   `brennan-lizzy-connelly`, `andy-katie-foy`, `shea-mickel-mcmahon`.
2. **The slug names one, the TITLE names both** — `david-hickson` is titled
   *"David and Linda Hickson Family"*; `isaac-nieto` is *"Isaac and Anna
   Nieto"*; `luke-edmiston` is *"Luke and Emma Edmiston"*.

Shape 2 is the one wave k missed entirely, and it is invisible unless you read
the title. **Always read the title, not just the slug.**

Grading, and it is not a judgement call:

| what you have | grade |
|---|---|
| slug carries this person's first name **and** the shared surname | `high` |
| slug omits them but the page title names them on a shared family page | `high` — and say so in `fit_reason` |
| neither the slug nor the title names them | **do not emit** |

## Children are not missionaries — new rule, read it twice

FOCUS profiles name spouses **and children**. The probe surfaced *"he and his
wife Kelly have seven children including Gianna"*. A name that appears as a
**child** must never become a record. They are not staff, they do not raise
support, and many are minors. If a snippet introduces a name with "their
children", "their kids", "son", "daughter", or a list of names after a
child-count, that name is out. If you cannot tell whether a name is a spouse
or a child, it goes to `needs_review`, not to `people`.

Emit **the missionary and the spouse. Nobody else on the page.**

## Slices — stay inside yours

Duplicated searches are wasted budget; a sibling has the rest.

### `focus-couples` → `couples.json`
The couple/family sub-surface across the whole site. Hunt both shapes above.
Rotate: `"and"` + married/family/couple wording, `-family` slugs, "serve
together", "met through FOCUS", "their children" (as a *page finder*, never as
a person source), Parish missionary couples, Area/Regional Director couples.
Two people per page is the whole point of this slice.

### `focus-campus-mw` → `campus-mw.json`
Campus axis, **Midwest + Great Plains**: Michigan, Michigan Tech, Wisconsin
(Madison, Eau Claire, Milwaukee), Minnesota, North/South Dakota, Iowa, Iowa
State, Loras, Missouri, Mizzou, Illinois, Indiana, Ohio, Ohio State, Nebraska,
Kansas, Kansas State, Creighton, Marquette, Notre Dame, Purdue.

### `focus-campus-east` → `campus-east.json`
Campus axis, **Northeast + Mid-Atlantic + South**: Penn State, Pitt, Rutgers,
UConn, Boston College, Villanova, Fordham, Syracuse, Maryland, Virginia Tech,
UVA, UNC, NC State, Clemson, Georgia, Georgia Southern, Auburn, Alabama,
Tennessee, Kentucky, Florida, UCF, USF, Miami, LSU, Ole Miss, Steubenville.

### `focus-campus-west` → `campus-west.json`
Campus axis, **West + Southwest + Mountain**: Arizona, Arizona State, Colorado,
Colorado State, Utah, Montana, Nevada, New Mexico, Texas, Texas A&M, Texas
Tech, TCU, Baylor, Oklahoma, Oklahoma State, Arkansas, UCLA, USC, Berkeley,
Santa Barbara, San Diego State, Cal Poly, Oregon, Washington, Gonzaga,
Benedictine, plus the nine international and nine Digital Outreach campuses.

### `focus-rare-names` → `rare-names.json`
First names wave k never tried. It swept common Anglo names to exhaustion, so
do **not** re-run Michael/Sarah/Matthew. Rotate: saint and devotional names
(Gianna, Kolbe, Xavier, Dominic, Therese, Zelie, Ignatius, Augustine, Cecilia,
Clare, Bernadette, Perpetua, Felicity, Pio, Isidore, Frassati), Irish/Italian/
Polish/German forms (Siobhan, Declan, Fiona, Gianluca, Lorenzo, Kasia,
Wojciech, Annika, Lukas), and Spanish/Portuguese/Filipino/African/Asian given
names (Mateo, Diego, Javier, Rocio, Guadalupe, Joao, Chinedu, Kwame, Thao,
Minh, Jae, Aditya, Pedro, Jianna).

## Do not re-search these

We hold **164 FOCUS people** already. The most-worked terms from wave k:
Aaron, Andrew, Anna, Ben, Brendan, Caleb, Caroline, Claire, Daniel, David,
Emily, Erin, Gabriel, Hannah, Jacob, James, John, Josh, Julia, Kate,
Katherine, Luke, Maria, Mark, Mary, Matthew, Michael, Monica, Nathan,
Nicholas, Olivia, Owen, Patrick, Paul, Peter, Priscilla, Rachel, Rebecca,
Ryan, Samuel, Sarah, Siena, Sophia, Thomas, Timothy, Veronica, William,
Zachary — plus campuses Texas A&M, Ohio State, Arizona State, Florida State,
Illinois, Minnesota, Notre Dame, Marquette, Purdue, Gonzaga, Steubenville,
Texas Tech, Oklahoma, Kansas, San Diego State, Creighton, Benedictine,
Franciscan, Nebraska-Lincoln, Louisiana-Monroe.

**This is a PLANNING HINT, NEVER A FILTER.** In wave h an agent read a held
list as a person-level exclusion and withheld 14 real people on a surname
match. If you find a person, emit them. The orchestrator dedupes against the
database — that is not your job and you will get it wrong, because FOCUS has
many people sharing a surname and several sharing a full name.

## Everything else

Follow `tools/hunter/prompts/enumeration.md` exactly: page fetching is
BLOCKED so work from titles, URLs and snippets; never cite a search-results
URL; never cite someone else's page; no first-name-plus-initial; sensitive or
anonymized workers go to `needs_review`; never record or infer anyone's
demographic or identity attributes; record queries that found **nothing** in
`coverage[]`; and **do not state a count in your closing message** — the JSON
file is the report.
