# Wave w2026-09-10h — CCO and RUF continuation

Rendered from `tools/hunter/prompts/enumeration.md`. Four agents, 18 searches
each (72). Model: Haiku 4.5.

## Why these two, and what changed

w2026-09-10g worked four untouched agencies. CCO returned 5.0 new/query with
zero citation defects and RUF 2.1; Campus Outreach (1.0) and Avant (0.67) are
not worth continuing. We hold 90 CCO and 37 RUF against rosters of roughly
300+ and 395.

Both were mined on ONE axis last wave — campus names — and both have an axis
that was never touched.

## CCO: the surname axis

CCO slugs are initial+surname (`gsalo` = Glenn Salo, `jburkholder` = Jennifer
Burkholder). That means **a surname is a searchable term against
`site:ccojubilee.org/staff`**, which campus qualifiers cannot reach.

The 90 surnames we hold have conspicuous gaps: **not one begins with J, N, Q,
U, X, Y or Z**, and D, L and O have a single entry each. That is a sampling
artifact of campus-based searching, not evidence CCO has no Johnsons.

Held surnames — do not spend searches rediscovering these:
Adams, Alexander, Beideman, Blaker, Bogertman, Bonomo, Bonzo, Bower,
Buffington, Burkholder, Campbell, Carl, Carlson, Case, Cavallaro, Chace,
Charles, Clark, Coelho, Daniels-Anderson, Dong, Evans, Feyrer, Fine, Francis,
Gephardt, Gigante, Goggin, Gongola, Greynolds, Gwynn, Hall, Harbison, Hayes,
Herman, Hill, Hoffman, Kalthoff, Levy, Mattes, Merrill, Miller, Moore, Morris,
Morton, Moser, Musselman, Myers, Origel, Pace, Pagel, Purcell, Rathbun, Repp,
Rice, Riemersma, Riethmuller, Rivas, Robinson, Rue, Ruffing, Saxton, Scalera,
Schiavoni, Schumacher, Scruggs, Shearer, Snoke, Staronka, Steffey, Stoltzfus,
Stone, Suggs, Sutherland, Swanson, Tanis, Thompson, Toren, Torres, Tyger,
Vargo, Wakeman, Walker, Weeber, Whitlock, Wiesen, Wilhelm, Willard, Willis.

## RUF: interns, and the campus-code space

RUF reports **170 campus ministers, 49 campus staff and 176 interns**. We hold
37, and **zero of them are interns**. Interns raise full personal support for
a two-year term — squarely Tier A and an entirely untouched population.

Two URL shapes on the giving platform, both confirmed last wave:
- `givetoruf.org/donate/<first.last>` — a person (high confidence)
- `givetoruf.org/donate/<campus-code>` — the ministry page for a campus, which
  names its minister (`vandy`, `bama`, `ncsu`, `ecu`, `fsu`, `gsu`, `hailstate`,
  `unf`, `utarlington`, `usc`, `vt`, `rice`, `duke`, `memphis`, `belmont`,
  `KentSt`, `brownrisd`, `columbus`, `vandyrufi`). Those 19 codes are SPENT.

Held RUF surnames: Adams, Askew, Boyd, Cassel, Choi, Coppedge, Crosby,
Danforth, Daws, Dixhoorn, England, Foster, Grider, Holdsworth, Holleman,
Hutchinson, Jackson, Kazanski, Larson, Little, Mahla, Mautz, McCann,
McLaughen, McWhite, Miller, Plybon, Rhodes, Shields, Straka, Swain, Tanner,
Terrell, Turner, Twit, Wilkerson, Wood.

## Spent qualifiers — do not re-buy

CCO campuses already searched: Penn State, Boston College, Ohio State, West
Virginia, Duquesne, Geneva, Kent State, Slippery Rock, Temple, Drexel, Grove
City, Indiana University of PA, Pittsburgh, Robert Morris, Shippensburg,
Millersville; roles: director, area, ministry, fellow, volunteer.

RUF already searched: Michigan, Wisconsin, Minnesota, Florida, Auburn, Ole
Miss, Clemson, Baylor, North Carolina, Virginia, Texas, Vanderbilt, Belmont,
Alabama, Mississippi, Florida State, Georgia (via ruf.org).

**No `-surname` exclusion tokens.** We hold 90 and 37; the technique is
measured to fail above ~15 held records per domain. Rotate fresh qualifiers.

## Assignments

| agent | target | slice |
|---|---|---|
| `cco-surnames` | CCO | common-surname sweep, weighted to the missing initials |
| `cco-campuses` | CCO | campuses not yet searched (western PA, Ohio, NY/NJ, New England, MD/VA) |
| `ruf-interns` | RUF | interns and campus staff by name on `givetoruf.org/donate/` |
| `ruf-campuses` | RUF | campus codes beyond the 19 already spent |

## Tiering

CCO staff, fellows and associates, and RUF campus ministers, campus staff and
interns, all raise personal support: **Tier A**. Do not downgrade for job
function or location.

**CCO volunteers are NOT Tier A** and must not be emitted as people — an
unpaid volunteer does not raise support. Seven were emitted last wave and
dropped at ingest. If a role string contains "Volunteer", put it in
`needs_review`.

Do not emit students.
