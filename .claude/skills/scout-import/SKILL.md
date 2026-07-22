---
name: scout-import
description: Import hunter (research subagent) findings into the DonorSend CRM scout queue (sales.scout_candidates). Use after running lead-discovery hunters, or whenever the user asks to load scout/lead candidates into the CRM.
---

# Scout Import: hunter findings → DonorSend CRM

Pipeline for loading lead-hunter output into `sales.scout_candidates` on the
DonorSend Supabase project (project_id: `leuhdxomjpoaiacxrwbz`), where it
appears in the CRM → Scout review queue for human approval.

## Step 0 — How hunters should write output

When spawning hunters, tell them to write ONE JSON file each (not SQL) to a
shared directory, as an array of:

```json
{"org_name": "...", "org_type": "individual|organization|ministry|missionary|church|nonprofit|other",
 "website": "...", "city": null, "state": null,
 "summary": "1-2 sentences incl. their public support-raising presence",
 "fit_score": 1-10, "fit_reason": "...", "source_query": "hunter:<angle>",
 "meta": {"src": "<source url>"}}
```

The importer also accepts legacy formats: SQL files with
`jsonb_to_recordset('[...]')` payloads (short keys n/t/w/s/f/r/q/m or long
keys), and `{"candidates": [...]}` JSON.

## Step 0b — (optional) give hunters a skip-list

To stop hunters re-finding contacts already in the CRM, before the hunt run
`export_existing.sql` via `execute_sql`, save the JSON result, then:

```bash
python3 tools/scout-import/scout_import.py snapshot existing.json --out <workdir>
# -> <workdir>/hunter_skiplist.txt  — paste into the hunter prompts
```

This is a convenience (fewer wasted searches); Step 2's import guards are the
real dedup and run regardless.

## Step 1 — Collect & generate batch SQL

```bash
python3 tools/scout-import/scout_import.py collect <hunter-output-dir> \
  --min-fit 6 --out <workdir>/scout_import_out
```

This normalizes, clamps fit scores, dedupes by org name AND by normalized
website (same person / different name spelling / same URL → merged; a URL
shared by 3+ records is a roster page and is kept, not collapsed), then
writes `import_batch_*.sql` + `verify.sql` + `manifest.json`. Report the
unique-record count and fit distribution to the user before importing.

## Step 2 — Execute against the database

Use the Supabase MCP `execute_sql` tool (it is in the project allow-list in
`.claude/settings.json`) with project_id `leuhdxomjpoaiacxrwbz`. First get a
baseline count:

```sql
select count(*) from sales.scout_candidates;
```

Then Read each `import_batch_*.sql` file and pass its full contents as one
`execute_sql` query, in order. Every batch is a single INSERT..SELECT with
NOT EXISTS dedup against both `sales.scout_candidates` and `sales.leads`,
so re-running a batch after a failure is safe and inserts nothing twice.

If `execute_sql` returns "requires approval", STOP and tell the user to
approve the permission prompt (or run the batches in the Supabase SQL
Editor themselves) — do not work around it.

## Step 3 — Verify (never skip)

Run the queries in `verify.sql` and report to the user:
- total rows vs baseline (delta = rows actually inserted)
- fit-score distribution
- duplicate-name count (must be 0)
- bad-status count (must be 0 — table check constraint allows only
  pending/approved/rejected/skipped)
- 5 newest rows as a sample

## Notes

- `ON CONFLICT DO NOTHING` does NOT dedupe this table (no unique constraint
  on org_name) — the NOT EXISTS guards are the dedup. Don't "simplify" them
  away. The website guard deliberately skips only *singleton* URLs
  (`es.n = 1`) so shared roster/platform pages never cause false skips.
- Fit scale: 9+ hottest, 7-8 solid, 6 marginal, <6 excluded by default.
- Only discover people/orgs with a PUBLIC support-raising presence (giving
  pages, prayer letters, ministry sites). Do not mine directories for
  contacts who aren't publicly fundraising — hunters will (correctly)
  refuse, and those leads perform worse anyway.
