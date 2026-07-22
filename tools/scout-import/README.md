# scout-import

Reusable pipeline for loading hunter (research subagent) findings into the
DonorSend CRM scout queue (`sales.scout_candidates`).

Born from the July 2026 hunter campaign, where 34 hunter output files in
three different formats had to be consolidated by hand: this tool does the
collect → normalize → dedupe → SQL-generation steps in one command, and the
generated SQL self-dedupes against the live database.

## Quick start

```bash
# 1. Point it at a directory of hunter output (.sql and/or .json files)
python3 scout_import.py collect ./hunts --min-fit 6 --out ./scout_import_out

# 2. Execute each scout_import_out/import_batch_*.sql against the DonorSend
#    Supabase project (SQL Editor, psql, or the Supabase MCP execute_sql tool).
#    Batches are idempotent — re-running inserts nothing twice.

# 3. Run scout_import_out/verify.sql and eyeball the results.
```

`report` does the collect/normalize/dedupe pass and prints stats without
writing SQL:

```bash
python3 scout_import.py report ./hunts --min-fit 8
```

## Accepted input formats

1. **Preferred (tell future hunters to emit this):** a JSON file per hunter,
   array of objects with keys `org_name, org_type, website, city, state,
   summary, fit_score, fit_reason, source_query, meta`.
2. SQL files containing `jsonb_to_recordset('[...]')` payloads — either
   long keys or the short-key style (`n,t,w,s,f,r,q,m`) hunters used
   historically.
3. `{"candidates": [...]}` wrapper JSON.

## What normalization does

- Maps short keys → canonical column names
- Clamps `fit_score` to 1–10, drops records without a name or numeric fit
- Coerces unknown `org_type` values to `ministry` (schema default)
- Strips `https://` and trailing `/` from websites (matches app convention)
- Stamps `meta.import_source` with the originating filename
- Dedupes by `lower(trim(org_name))`, keeping the highest-fit copy
- **Then dedupes by normalized website** (scheme/`www.`/trailing-slash
  stripped), which catches the same person under two name spellings
  (e.g. "Aaron & Stacy Jex" vs "Aaron and Stacy Jex" on the same URL).
  A URL shared by 3+ records is treated as a roster/platform page, not
  one person, and is **not** collapsed — so distinct missionaries who
  all cite an agency deputation list are preserved.

## Avoiding duplicates against the live CRM

Two layers guard against re-importing contacts you already have:

1. **Import-time (automatic):** the generated SQL skips any candidate whose
   name matches an existing `sales.scout_candidates` or `sales.leads` row,
   **or** whose website matches an existing *person-specific* URL (one that
   appears on exactly one existing row — shared roster URLs never trigger a
   skip). This is the real safety net; re-running a batch is always safe.

2. **Hunt-time (optional, saves wasted searches):** before launching a new
   hunter wave, export what the CRM already has and hand hunters a skip-list:

   ```bash
   # 1. Run export_existing.sql via the Supabase execute_sql tool, save the
   #    JSON result to existing.json
   # 2. Turn it into a prompt snippet:
   python3 scout_import.py snapshot existing.json --out ./snap
   # -> ./snap/hunter_skiplist.txt  (paste into hunter prompts)
   ```

   Hunters still occasionally re-find known contacts; layer 1 catches those.
   The skip-list just means they spend fewer searches doing so.

## Why the generated SQL looks the way it does

`sales.scout_candidates` has no unique constraint on `org_name`, so
`ON CONFLICT DO NOTHING` cannot dedupe. Each batch is an `INSERT..SELECT`
with `NOT EXISTS` guards against both `sales.scout_candidates` and
`sales.leads`, making every batch idempotent and duplicate-safe.

See `.claude/skills/scout-import/SKILL.md` for the end-to-end session
workflow (collect → execute via MCP → verify).
