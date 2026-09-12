# Agencies already in the database — generated, not remembered

Regenerate before writing any brief:

```sql
select coalesce(meta->>'target_org', regexp_replace(split_part(source_url,'/',3),'^www\.','')) as org,
       count(*) from sales.scout_candidates
where org_type='individual' and source_url is not null
group by 1 having count(*)>=3 order by 2 desc;
```

Wave w2026-09-10n spent most of a slice rediscovering World Wide New
Testament Baptist Missions because the brief's already-worked list was
written from memory and omitted it. Do not write that list from recall.

## Also check the rejections, not just the holdings

`scout_candidates` tells you which agencies you have *mined*. It does not tell
you which you have already *rejected*, and those are just as expensive to
re-probe. Run this too:

```sql
select name, reason_code, source from sales.hunt_negatives
where entity_kind='org' order by name;
```

In w2026-09-11s the orchestrator probed eight agencies before dispatch and two
of them — Christar and Team Expansion — had already been probed and rejected in
w2026-09-10n. Two wasted searches is cheap; the same mistake at agent scale is
not. Both lists, every time.

## Snapshot, 2026-09-11 (4,409 approved people)

**Heavily worked (100+):** Ethnos360 534 · FOCUS 522 · One Mission Society
230 · Reformed University Fellowship 222 · Baptist Mid-Missions 206 · BIMI
153 · World Gospel Mission 144 · Cadence International 142 · Resonate
Global Mission 139 · Coalition for Christian Outreach 119 · Mission
Aviation Fellowship 110 · SEND International 100

**Substantially worked (30–99):** WWNTBM 98 · Fundamental Baptist Missions
Intl 87 · Converge 83 · Christian Missionary Fellowship Intl 66 · Africa
Inland Mission 64 · Family Missions Company 61 · Greater Europe Mission 61
· The Traveling Team 57+4 · Saint Paul's Outreach 49 · Encompass World
Partners 47 · Macedonia World Baptist Missions 43 · CMML 41 · Free
Methodist World Missions 38 · Independent Baptist Fellowship Intl 38 ·
Young Life 36 · Campus Outreach 35 (+ regional rows)

**Lightly worked (3–29):** Youth for Christ USA 25 · InterVarsity 23 ·
Medical Teams Intl 20 · Christar 18 · Medical Missionaries 16 · Wycliffe 15
· Cru 14 · Christian Health Service Corps 13 · Mesa Global 13 · Mercy Ships
13 · Seed Company 12 · Avant 12 · New International 10 · East-West
Ministries 9 · Fellowship Intl Mission 9 · Mission to the World 9 · Multiply
8 · Serge 8 · YWAM 8 · Youth Apostles 8 · Global Gates 8 · The Navigators 6
· Liebenzell USA 5 · Flying Doctors 5 · Volunteers in Medical Missions 5 ·
ABWE 4 · Pioneers 4 · SIM USA 4 · Assemblies of God World Missions 4 · WEC
Intl 3 · TEAM 3 · World Medical Mission 3 · Ratio Christi 2

## Two things this list reveals

1. **Several agencies I have treated as "untouched" are not.** Resonate,
   MAF, AIM, CMFI, Family Missions Company and The Traveling Team all carry
   real headcounts from early waves. Check here first.
2. **There is non-ICP debt in the table.** Rows attributed to food banks
   (Atlanta Community Food Bank, Harry Chapin, Treasure Coast, Good
   Shepherd, Food Bank for the Heartland), Homes for Our Troops, and
   platform domains (givesendgo.com, donorbox.org, givebutter.com,
   continuetogive.com) are not support-raised missionary staff and should
   be reviewed out. Roughly 60–80 rows. Not urgent, but it inflates the
   headline count.

## The holdings check, done properly (2026-09-12)

`AUDIT-2026-09-12.md` replaces the list above as the authoritative answer to
"have we worked this agency". The list is a snapshot; the query is not.

**Before dispatching a wave, run this — keyed on org name and the FK, never on a
domain you typed from memory:**

```sql
select t.id, t.org_name, t.website, t.roster_status, t.headcount_found,
       count(c.*) held, count(*) filter (where c.status='approved') approved
from sales.hunt_targets t
left join sales.scout_candidates c
  on  c.org_type in ('individual','Individual','missionary')
  and (c.hunt_target_id = t.id
       or btrim(regexp_replace(lower(translate(coalesce(c.meta->>'target_org',''),'.''-"/,&',' ')),'\s+',' ','g'))
        = btrim(regexp_replace(lower(translate(t.org_name,'.''-"/,&',' ')),'\s+',' ','g')))
where t.org_name ilike '%<agency>%'
group by 1,2,3,4,5;
```

`roster_status` and `headcount_found` are **not** trustworthy on their own: the
audit found 32 targets reading `unrostered, 0` that already held people, including
BIMI (153), Converge (105), FBMI (94) and AIM (82). Those are now `partial`.

Domain matching is for confirmation only. 93 targets share `usachurches.org`,
eleven Campus Outreach locals share two regional staff pages, and `Ratio Christi -
Board` swallows 59 people belonging to `Ratio Christi`.

## Two more kinds of debt in the table

3. **Competitor platforms are not recorded.** 109 person records sit on
   `modernday.org/profile/` — Modern Day Missions runs its own donor-management
   and giving software for ~1,700 missionaries. 96 of those records are approved.
   `hunt_targets.crm_incumbent` exists and is empty on every row. Person records
   now carry `meta.platform_incumbent`; the target-level column is still unused.
4. **Nine people are cited to organisation directories** (GuideStar, BBB). An org
   profile cannot evidence an individual's support-raised role. Tagged
   `meta.citation_quality = 'org_directory'`.

## Never sweep on a keyword alone

The short-term audit would have destroyed good data if run as a keyword sweep:
78 RUF records say "intern" and the RUF internship is a **two-year, support-raised
role**; the BIMI records that say "trip" are career missionaries who **host** trips.
Only two genuine short-term participants existed in 6,691 records, and both had
already been scored 5.
