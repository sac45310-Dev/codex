# Triage plan for the 1,263 pending organisations — 2026-09-12

The organisation queue in `scout_candidates` has never been triaged. This
document says what is actually in it, proposes a bucket-by-bucket disposition
with the SQL to do it, names the decisions that are the owner's and not mine,
and lays out the structural fix so the queue does not refill.

**Nothing in this plan has been executed.** Every step is reversible by design
and every bulk write captures a reversal table first, as the session's other
bulk writes have.

---

## 1. What the 1,263 actually are

**Two findings change the shape of the job before any triage starts.**

### 40% of the "organisation queue" is people

A classification dry-run over all 1,263 rows:

| bucket | rows | scored | has site | person-shaped name |
|---|---|---|---|---|
| **0a — person misfiled, `missionary_hunt` import** | **430** | 0 | 72 | 404 |
| **0b — person misfiled, other imports** | **70** | 35 | 70 | 47 |
| 1 — local church | 269 | 30 | 205 | 1 |
| 2 — church-planting network | 28 | 0 | 2 | 2 |
| 3 — counselling practice / counsellor | 45 | 0 | 45 | 0 |
| 4 — organisation from `missionary_hunt` import | 78 | 0 | 4 | 0 |
| 5 — scored organisation (`FINAL_CONSOLIDATED`) | 271 | 258 | 271 | 0 |
| 6 — residual | 72 | 20 | 67 | 3 |

**500 rows are people.** A July 26 import (`missionary_hunt`) wrote each person's
*name* into `org_name`, their *agency* into `source_query` as
`"<Agency> - Missionary"`, and set `org_type = 'Missionary Organization'` — a
value no code path recognises. Samples: *Byron Villarreal — Missionary*,
*Kelly Solheim — Missionary Volunteer Partner*, *Steve DeBuhr — Senior Advisor
to the President*, *Luther Bradley — Board Trustee (Semi-retired)*, and
**`Brandon`** — a first name alone, which under the protection rules must never
be resolved from another source.

These rows were invisible to both people triages this session because both
filtered on `org_type = 'individual'`. They are not a triage problem; they are
a **data-entry defect**, and the fix is to re-type them and put them through
the people pipeline that already exists.

### The org queue and `hunt_targets` are two disconnected systems

Of 1,263 pending orgs, **8 match a `hunt_targets` row by name and 2 match
`hunt_negatives`.** The 824 targets — the table every wave, audit and holdings
check has used — were built from `backfill:approved`, wave discovery and seeds
*after* these rows landed. The org queue is a July artefact that the September
tooling never looked at.

That also means the 1,263 have never been through the giving-domain test, the
holdings check, or the negatives ledger — the three things that now decide
whether an agency is worked. **Triage here is mostly migration**: moving real
organisations into `hunt_targets` where those tools apply, and moving people
into the people table where the protections apply.

### What "approve" means for an organisation row

`tools/hunter/sql/promote_orgs_to_leads.sql` turns approved records into
`sales.leads` — one lead per organisation, scored by confidence-weighted Tier A
headcount. Approving an org row is therefore not a queue state; it creates a
CRM account. That raises the bar on this triage relative to the people queue.

---

## 2. Disposition by bucket

Every bucket below gives: what it is, the decision, how it is done, and what is
the owner's call. Reversal table naming: `sales.org_triage_20260912_<bucket>`.

### 0a — 430 people misfiled from `missionary_hunt` → re-type and run the people pipeline

**Do not triage these as organisations.** Re-type to `individual`, recover the
agency from the source string, then hand them to the existing people process.

The source strings are mechanical enough to parse:

| source shape | rows | example → `target_org` |
|---|---|---|
| clean `<Agency> - Missionary` | 443 | `World Gospel Mission - Missionary` → `World Gospel Mission` |
| couple name + `(Agency)` | 21 | `Mark & Janet Baxter (YWAM Jacksonville) - Missionary` → `YWAM Jacksonville` |
| `Agency / Sub-entity - Missionary` | 12 | `Youth for Christ International / Youth for Christ Ecuador` → keep both, parent as `target_org` |
| `Agency, Qualifier - Missionary` | 10 | `Youth for Christ USA, Board of Trustees` → agency `Youth for Christ USA`, role hint `Board` (Tier C) |
| bare `missionary_hunt` | 22 | no agency recoverable → `needs_review` |

83 distinct agencies. Many are **already worked**: BIMI (153 held), FBMI, WWNTBM,
Ethnos360, WGM, MAF (110), The Navigators, Young Life, YFC, Wycliffe (316), Cru.
So most of these people will dedupe against holdings; the residue is the yield.

**Then apply the people rules already in force**, in this order:

1. **Dedupe** by normalised name against the 6,887 person rows (56 already collide).
2. **Protections.** First-name-only (`Brandon`) → never emitted, never resolved;
   `Board Trustee (Semi-retired)` → Tier C with the retiree flag; `Missionary
   Volunteer Partner` → the volunteer flag. Per the owner's 2026-09-12 decision,
   flags annotate, they do not block.
3. **Evidence basis.** These rows carry `meta.donation_page`, `linkedin_url`,
   `tenure_years`, `confidence`. Map: `donation_page` present → `personal_page`,
   `high`, 9; otherwise `org_policy` (the agency is known to support-raise),
   `medium`, 7. Never `unverified`.
4. **Link** `hunt_target_id` by agency name and acronym — `legacy_acronym_mapping.sql`
   already exists for exactly this (BIMI, WWNTBM, FBMI, MWBM, IBFI…).
5. **Faith orientation is the owner's call, never the agent's.** 13 rows are
   *The Church of Jesus Christ of Latter-day Saints — Area Authority Seventy*.
   `hunt_targets.faith_orientation` exists for this; it is set by hand.

```sql
-- 0a: re-type, recover agency, preserve provenance. Reversal captured first.
create table sales.org_triage_20260912_0a as
  select id, org_name, org_type, status, meta from sales.scout_candidates where <bucket 0a predicate>;
update sales.scout_candidates set
  org_type='individual',
  meta = meta || jsonb_build_object(
    'target_org', regexp_replace(regexp_replace(source_query,' - Missionary$',''), '^.*\((.*)\)$', '\1'),
    'retyped_from','Missionary Organization','retyped_on','2026-09-12',
    'evidence_basis', case when coalesce(meta->>'donation_page','')<>'' then 'personal_page' else 'org_policy' end,
    'confidence',     case when coalesce(meta->>'donation_page','')<>'' then 'high' else 'medium' end)
where <bucket 0a predicate>;
```

### 0b — 70 people misfiled from other imports → re-type, then apply the ICP

Gospel Coalition church-directory pastors (*Timothy Shutes — Citylight Church
NYC*), personal ministries (*Hunter Gospel Foundation — Rev. Raymond Hunter*),
blog-shaped rows (*The Pastor's Page*). Re-type as in 0a, but note most are
**pastors of local churches — salaried, not support-raised**, which is the
`church_salaried` reason code already used 215 times in this database. The
exception is a **church planter**, who is Tier A. Expect most of these 70 to be
rejected on the people side, not approved.

### 1 — 269 local churches → reject `church_salaried` (owner's call)

Saskatchewan (59) and Nova Scotia (13) churches "Led by X & Y", the blank-source
Baptist churches, Mountain West churches, and everything with *church / baptist
/ tabernacle / chapel* in the name. A local church has no personally
support-raised staff as a rule; `church_salaried` is the most-used reason code
in `hunt_negatives` (115) and `hunt_targets` (100). **The precedent is
unambiguous, but it is still the owner's call** — 269 here plus 93
`usachurches.org` rows in `hunt_targets` is a lot of doors to close at once.

The one exception matters: a **church plant with a named planter raising
support** is Tier A — captured as the *planter*, a person, not as the church.
The 0b re-type catches those.

```sql
update sales.scout_candidates set status='rejected',
  review_note='[org triage 2026-09-12] Local church: pastors are salaried, not personally support-raised (church_salaried). Owner-approved bulk rejection.'
where <bucket 1 predicate>;
insert into sales.hunt_negatives (entity_kind,name,website,reason_code,source)
  select 'org', org_name, website, 'church_salaried', 'org-triage:2026-09-12' from ... on conflict do nothing;
```

### 2 — 28 church-planting networks → promote to `hunt_targets`, probe

*Send Network* (SBC), *Converge Church Planting*, *EFCA Northwest*, *Foursquare
Multiply*, *Acts 29 Urban Network*. Their planters raise support, so the
network is a genuine agency-shaped target. **Dedupe first**: `Converge` is
already target 824 with 105 people held. Promote the rest as `org_type =
'network'`, `unrostered`, `discovered_by = 'org-triage:2026-09-12'`, then run
the giving-domain test before any wave. Expect *Send Network* to fail it
(NAMB-funded, pooled) and *Acts 29* to be a network of churches rather than a
roster.

### 3 — 45 counselling practices → reject `business_vendor`

*Alicia Gutierrez Counseling*, *Eldora Brock Counseling* — private-practice
counsellors, all with `website = ccef.org` (a training body, not their site).
They sell services; they do not raise support. `business_vendor` is the existing
code (20 uses). Also 40 rows carry counselling-flavoured `org_type` values
(*Biblical Counseling Ministry*, *Pastoral Counseling Network*…) — same
disposition.

### 4 — 78 organisation-shaped rows from `missionary_hunt` → dedupe, promote

*AIM*, *BIMI*, *Ethnos360*, *The Navigators*, *Wycliffe Bible Translators*,
*Coalition of Churches in Prison Ministry*, *Deaf 316 Ministries*. Most are
agencies **already in `hunt_targets` under a longer name** (`BIMI` vs *Baptist
International Missions, Inc.*). Match by normalised name **and by acronym**
using `legacy_acronym_mapping.sql`; link the matches (`status = 'skipped'`,
`review_note` pointing at the target id) and promote the genuinely new ones as
`unrostered`.

### 5 — 271 scored organisations → keyword pre-screen, then the giving-domain test

These are the only rows that look like an org triage was intended: real names,
real sites, summaries, enrichment, `fit_score` 7–9. But the scoring came from
an earlier, looser ICP — *NETWORK Lobby* (Catholic advocacy) scored 8, *Be The
Bridge* 7, *EveryLife Foundation for Rare Diseases* 8. None of those has
support-raised staff.

A keyword pass over the summaries settles a fifth of them for free:

| pre-screen verdict | rows | disposition |
|---|---|---|
| reject: advocacy / policy / lobbying | 25 | `too_institutional` |
| reject: school / seminary / university (salaried) | 23 | `school_salaried` |
| reject: media / publishing / radio | 6 | `business_vendor` |
| reject: healthcare institution | 1 | `too_institutional` |
| **probe: support-raised signal in summary** | **19** | promote, priority |
| **probe: no signal either way** | **232** | promote, screening wave |

The 251 to probe go to `hunt_targets` as `unrostered`, and then get the test
wave w2026-09-12a put in the template: *does the agency's own giving domain
return more people than programmes?* One search per org, `blocked_domains:
["en.wikipedia.org"]` on every query, unconditional rules, output = a verdict
per org, not people. **~250 searches, about ten agents.** That is the one real
spend in this plan, and it is the step that turns 251 guesses into a ranked list
of dispatchable agencies.

### 6 — 72 residual → by hand

Small enough to read. Mixed: *Acts 29 Urban Network* (belongs in bucket 2),
*Crystal Bridge Community Church* (bucket 1), *Ministry Essentials* (a vendor).
An hour with the list.

---

## 3. Decisions that are the owner's — answered 2026-09-13

Decisions 1–4 were given on 2026-09-13 and are now rules in
`prompts/enumeration.md` under *Owner scope rules*. Decision 5 is still open.

| # | decision | answer |
|---|---|---|
| 1 | Local churches out of ICP? | **Yes, out.** `church_salaried`. Planters are Tier A *people*. |
| 2 | Pastors filed as organisations? | **Out**, unless staff of a non-church-affiliated non-profit or ministry. |
| 3 | Faith orientation | **Christian (any variation), Catholic, or non-religious only.** LDS/Mormon, other faiths and interfaith bodies out. Owner-set; agents flag, never classify. |
| 4 | Canadian organisations | **In scope**, alongside US. |
| 5 | Run the ~250-search screening wave, or hand-pick the 19 first? | *open* |

**Added the same day — owner keyword exclusions.** Organisations that promote
or reference LGBT / LGBTQ+ / gay / lesbian / queer / transgender / nonbinary /
Pride / "gender identity" / "gender affirming" / "gender diverse" / "sexual
orientation" / "Two-Spirit" are rejected with `reason_code = keyword_exclusion`
until the product adds the functionality such organisations would need. The
rule matches organisation rows only — never a person's record — and the
standing prohibition on inferring any individual's attributes is unchanged.
Full text and the scope boundary are in the template.

The original wording of the questions, for the record:

1. **Are local churches out of ICP?** 269 rows here, 93 more in `hunt_targets`.
   Precedent says yes (`church_salaried` ×215). Confirm, or name the exception.
2. **Pastors filed as organisations** (bucket 0b) — same question from the
   person side.
3. **`faith_orientation` for the 13 LDS rows** and any other non-Christian or
   secular org the triage surfaces. Set by hand; agents never classify it.
4. **Canadian organisations** (72 Saskatchewan / Nova Scotia rows). Nothing in
   the ICP says US-only; if it should, say so and it becomes a rule.
5. **Whether to run the ~250-search screening wave in bucket 5**, or to
   hand-pick from the 19 with a visible support-raised signal first.

---

## 4. Making future organisations behave

The root cause is not that 1,263 rows went untriaged. It is that **there was
no gate**: the legacy import wrote whatever it was handed into
`scout_candidates`, with a free-text `org_type` (43 distinct values today, none
constrained), and no check on whether the row was a person or an organisation
or already known. Five changes close that.

### A. One table per entity kind

`hunt_targets` is the organisation record — it has `roster_status`,
`faith_orientation`, `do_not_pursue`, `crm_incumbent`, `reject_reason`, and
every tool in the pipeline reads it. `scout_candidates` is the person record.
**No organisation should ever be inserted into `scout_candidates` again.**

A table `CHECK` cannot be added while 2,012 legacy org rows exist. A trigger
can, and only bites new writes:

```sql
create or replace function sales.scout_candidates_people_only() returns trigger as $$
begin
  if lower(coalesce(new.org_type,'')) not in ('individual','missionary') then
    raise exception 'scout_candidates is for people; org_type=% belongs in sales.hunt_targets', new.org_type;
  end if;
  return new;
end $$ language plpgsql;
create trigger scout_candidates_people_only before insert on sales.scout_candidates
  for each row execute function sales.scout_candidates_people_only();
```

Once this triage has migrated the legacy org rows out, replace the trigger
with a real `CHECK (org_type in ('individual'))` and normalise the 43 values to
one.

### B. Fix the legacy import path in `scout_import.py`

`tools/scout-import/scout_import.py` lines 107–110 coerce any unrecognised
`org_type` to `'ministry'` — which is how *Missionary Organization* would enter
today as an org. The wave path (`ingest_wave`, line 405) already does the right
thing: `orgs_discovered[]` goes to `hunt_targets` with `NOT EXISTS` guards
against both `hunt_targets` and `hunt_negatives` (lines 549–562). Make the
legacy `import` path use the same routing:

- non-`individual` record → emit to the `hunt_targets` batch, never to
  `scout_candidates`;
- `individual` record without `target_org` and `evidence_basis` → `needs_review`,
  not inserted.

### C. A name-shape tripwire

The regex that found the 459 person-shaped org names in this queue would have
caught all 500 misfiles at ingest:

```
^[A-Z][a-z]+(\s[A-Z]\.?)?(\s(&|and)\s[A-Z][a-z]+)?\s[A-Z][A-Za-z'-]+(\s\([^)]*\))?$
  and not ~* (church|ministr|mission|fellowship|foundation|network|alliance|…)
```

Add it as an ingest check: a person-shaped name on a non-`individual` record
is refused with a message, not coerced. It is a tripwire, not a classifier —
the human decides.

**Known bias, found in execution.** That pattern requires a plain
`Firstname Lastname` and so **systematically under-catches titled and non-Anglo
names** — *Dr. Stephen Coertze*, *Rev. Abson P. Joseph*, *Chee Hoe Koay*,
*Antoinette Van Kuik*, *Viktor Rózsa* all slipped past it into the
"organisation" bucket. Two fixes, both applied on 2026-09-13:

- In an import whose source already says the rows are people (`"<Agency> -
  Missionary"`), **invert the default**: everything is a person unless the name
  carries an organisation word. Do not ask a regex to recognise people; ask it
  to recognise organisations, which is the smaller and more regular set.
- Where a person-shape test is still needed, strip honorifics (`Dr.`, `Rev.`,
  `The Revd`, suffixes like `Jr`, `APR`) and allow particles and accented
  letters before matching.

### D. The organisation triage rubric, in order

Every new organisation, whether from an import or a wave's `orgs_discovered[]`,
answers these in sequence. The order matters because each step is cheaper than
the next and the early ones remove most rows.

| step | question | mechanism | outcome |
|---|---|---|---|
| 1 | Do we already know it? | normalised name **and acronym** vs `hunt_targets`; registrable domain to confirm, never to decide; name vs `hunt_negatives` | link, or stop |
| 2 | Is it an organisation at all? | name-shape tripwire | re-type as person |
| 3 | Is it a local church, or a keyword-excluded organisation? | rule 1 (`church_salaried`) and the owner keyword list (`keyword_exclusion`) against the org's own name/site/summary | `rejected` + reason + negative |
| 4 | Does it have personally support-raised people? | keyword pre-screen on the summary, then the giving-domain test: *does its own domain return more people than programmes?* | `unrostered` + priority, or `rejected` + reason |
| 5 | Faith orientation | **owner sets it** — Christian / Catholic / non-religious in, all else out; agents flag, never infer | `faith_orientation`, or `rejected other_faith` |
| 6 | Do not pursue | **manual review only**; agents never classify | `do_not_pursue` |

Rejections always write a `hunt_negatives` row with the reason code, so the
same org cannot be re-discovered and re-probed by a later wave — the lesson
from CrossWorld, Pioneers, World Team and SIM USA, each of which a wave nearly
re-probed before the ledger was checked.

### E. One vocabulary, and negatives that are amended, not deleted

`hunt_targets.org_type` currently holds `agency` *and* `mission_agency`,
`ministry` *and* `parachurch` *and* `youth_ministry`. Constrain it to
`{agency, mission_board, network, ministry, nonprofit, church, denomination}`
and map the strays. Reuse the reason codes already in use — `church_salaried`,
`too_institutional`, `business_vendor`, `school_salaried`, `platform_not_person`,
`no_per_person_surface`, `pooled_fund`, `denomination`, `duplicate_of_parent`,
`duplicate_target` — rather than inventing new ones. When a negative turns out
to be wrong (Wycliffe 322, InterVarsity 63), set `reason_code = 'reversed'` and
append the correction: the mistake stays visible, and the reopened target
carries the note.

---

## 5. Execution order and what it costs

| step | what | cost | reversible |
|---|---|---|---|
| 1 | Re-type the 500 people (0a, 0b), recover agencies, run people dedupe + protections + linkage | SQL, ~1 hr | yes |
| 2 | Owner confirms decisions §3.1–3.4 | — | — |
| 3 | Reject buckets 1, 3, and the 55 keyword-screened from 5; write negatives | SQL, minutes | yes |
| 4 | Promote buckets 2, 4, 5-probe to `hunt_targets` with acronym dedupe | SQL, ~1 hr | yes |
| 5 | Screening wave on the ~250 promoted: one search each, verdict per org | ~10 agents | n/a |
| 6 | Bucket 6 by hand | ~1 hr | yes |
| 7 | Trigger (§4.A), import-path fix (§4.B), tripwire (§4.C), vocabulary (§4.E) | one code PR | yes |

After step 1, the "organisation queue" is 763 rows, not 1,263. After step 3 it
is about 400. After step 4 it is empty — everything real lives in
`hunt_targets` where the waves can see it, and everything else has a reason
code in the ledger.

---

## 6. Execution notes — 2026-09-13

Steps 1, 3, 4 and 6 of §5 were executed on 2026-09-13 once decisions 1–4 were
given. Counts are in the commit that carries this section. Two operational
findings from the run belong in the plan itself, because they will bite the
next person too.

### `hunt_targets` has a per-row trigger that makes bulk inserts slow

`hunt_target_link_candidates()` fires `AFTER INSERT OR UPDATE OF website,
org_name … FOR EACH ROW` and runs:

```sql
update sales.scout_candidates c set hunt_target_id = r.target_id
  from (select c2.id, sales.resolve_hunt_target(c2.website, c2.org_name)
          from sales.scout_candidates c2
         where c2.hunt_target_id is null
           and (sales.url_domain(c2.website) = sales.url_domain(new.website)
                or lower(trim(c2.org_name)) = lower(trim(new.org_name)))) r
 where c.id = r.id and r.target_id is not null;
```

That is a regex over every unlinked candidate row, once per inserted target.
Inserting 291 targets ran past two minutes and timed out twice at the tool
layer. The work it does — linking people to their target by domain or name —
is worth keeping; the shape is not. **For any insert of more than a handful of
targets: disable the trigger, insert, re-enable it in the same transaction so
it cannot be left off, then do the linking once as a set-based join over the
new targets only.** A longer-term fix is to rewrite the trigger as a statement-
level trigger over the transition table, which is the same join.

### The tool's 60-second timeout does not cancel the server query

Both timed-out attempts kept running on the server after the tool gave up —
the second was found still `active` in `pg_stat_activity` nearly two minutes
later, holding its transaction open. Nothing committed, so no harm, but a
retry issued while the first is still running blocks on its locks and looks
like a second slow query. **Every write now begins with
`SET LOCAL statement_timeout = '50s'`** so the server cancels first and there
is never a ghost query to chase; and any write that might be slow gets its own
call rather than sharing a batch with table creation, so a timeout can never
leave the question "did the earlier statements commit?" open.

### The person-shape regex has a bias (see §4.C)

It under-catches titled and non-Anglo names. Fifty-one people in the
`missionary_hunt` import were classified as organisations because of it
(*Dr. Stephen Coertze*, *Chee Hoe Koay*, *Antoinette Van Kuik*). The correct
default for an import whose source says the rows are people is to treat
everything as a person unless the name carries an organisation word.
