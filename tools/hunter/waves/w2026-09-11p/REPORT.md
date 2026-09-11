# Wave w2026-09-11p — Ratio Christi, Youth Apostles, Women Youth Apostles

Four agents, 72 searches, **67 net new people — 0.93 per query.** Below the
retirement line in aggregate, but the aggregate is misleading: one target
was strong and two were structurally closed.

| target | searches | net | rate | verdict |
|---|---:|---:|---:|---|
| Ratio Christi (2 agents) | 36 | 57 | **1.6** | open, worth a fetch pass |
| Youth Apostles | 18 | 3 | 0.17 | search-defeated |
| Women Youth Apostles | 18 | 7 | 0.39 | **closed** |

Ratio Christi 59 held (58 Tier A). Database total 4,548.

## The screening question resolved structurally

I briefed this wave expecting a judgement call on volunteer vs supported
chapter directors. **Both agents found something better: Ratio Christi
encodes the split in the URL path itself.**

`give.ratiochristi.org/missionary/<name>` is the **supported** track.
`give.ratiochristi.org/volunteer/<name>` is the **tent-maker** track.

The org documents both Chapter Director tracks on its own application
page — supported missionaries are paid from funds they raise through
their own Ministry Partners; volunteers skip parts of the application.
The `ratio-b` agent found the discriminator by cross-checking named
chapter directors against the giving domain: Eric Chabot, the Ohio State
chapter director, resolves to `/volunteer/eric-chabot`.

**Volunteers are not distinguishable by job title.** They hold the same
"Chapter Director" title as supported staff. Grading this roster by role —
which is what a normal wave would have done — would have put volunteers
into a sales queue. Five are logged as screening exclusions: Runyan,
Chabot, Rodseth, Castro, Tabladillo.

**One case breaks the clean rule**, and it is recorded rather than
smoothed over: Eric Scott has a `/missionary/` page whose own copy
describes him as a volunteer on the national leadership team. The path is
a strong signal, not proof. A fetch pass grepping the 58 emitted URLs for
"volunteer" would retire the residual risk in one request.

## Two Ratio Christi findings that change how to use it

- **The supported roster is a minority of the chapter-director
  population.** Named directors at Maryville, UT Austin and NC State had
  no giving page in 18 searches. Ratio Christi advertises chapters at far
  more campuses than it has indexed giving pages. **Do not extrapolate
  chapter count into prospects.**
- **Home-office executives are personally support-raised.** The president
  and the COO both carry their own `/missionary/` pages. Tiering HQ staff
  down on job function would be wrong here — the opposite of the usual
  assumption.

Also: `ratiochristi.org/people/` is *not* a staff roster — it mixes
employed staff with academic advisory-board names, and Rick James appears
in it *and* has a giving page, so the directory alone cannot tell them
apart.

## My briefed tactic failed, and failed structurally

I told the Youth Apostles agent to use the literal title suffix
`"| Youth Apostles"`. **That was a bad instruction.** The suffix appears
in the title of every page on the site, program pages included, so it has
zero discriminating power. Both sweeps returned only hubs. Retired rather
than retried.

What the agents found instead is more useful than what I asked for:

- **Bare `site:` queries get hijacked by Wikipedia** whenever the query
  carries a saint's or a school's name — one parish sweep returned seven
  Wikipedia church articles and zero on-domain results. Switching to
  `allowed_domains` fixed it completely, every time. **Prefer
  `allowed_domains` over `site:` on small domains with name collisions.**
- A second URL shape exists, `youthapostles.org/author/<slug>`
  (WordPress author archives), but two queries against it surfaced one
  author. Not the back door it looked like.

Youth Apostles' real blocker: `/missionaries` surfaced in 8 of 18 queries
and every time returned its placement headings and never the names
underneath. That page holds the actual Tier A population and search
cannot reach into it.

## An ICP exclusion I made at ingest

The Youth Apostles agent emitted three ordained **consecrated members** —
Eric McDade, Sean Mazary and Jim Harbour, ordained 2026-06-06. Youth
Apostles' own vocations page says consecrated priests and lay brothers
make promises of poverty, chastity and obedience and live in community
houses.

**A person under a promise of poverty does not manage a personal donor
base, which is the entire product.** I did not emit McDade or Mazary, nor
Fr. Jack Peterson or Fr. Tom Yehl, and recorded all four in
`hunt_negatives` with the reasoning so no future wave re-adds them.

Jim Harbour is the awkward case: he was already held **Tier A from wave n**
on a personal page of the same shape the missionaries use. That grading is
now in doubt. I set his record to `pending` and wrote the conflict into
`fit_reason` rather than silently keeping or deleting it — this is a human
call, not mine.

Also excluded: "John Lilly", emitted as an unverified blog author, and a
"Fr. Jack" named without a surname.

## Women Youth Apostles is closed

No per-person surface, no per-person giving URL, every post filed under a
single site-wide author, and the Youth Apostles root-slug shape does not
exist there. Only two directory pages name anyone.

The community states its 23 members serve "as volunteers and staff" and
documents no support-raising. I took the 7 named council and local
directors as **Tier B influencers at fit_score 5**, with the volunteer
caveat written into every `fit_reason`, rather than as support-raisers.
That is the same gate I applied to Ratio Christi, applied consistently.
The domain is recorded in `hunt_negatives` as closed.

## Coverage

77 rows (71 queries + 6 URLs).

## Next

Wave q: the unprobed Baptist agencies — Evangelical Baptist Missions,
BBFI, Independent Faith Mission, Bible Baptist Missions, Baptist Church
Planters, and Continental Baptist Missions on its correct domain (wave n
probed `cbmin.org`, which is Canadian Baptist Ministries).
