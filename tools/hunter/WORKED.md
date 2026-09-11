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
