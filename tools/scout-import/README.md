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

## Why the generated SQL looks the way it does

`sales.scout_candidates` has no unique constraint on `org_name`, so
`ON CONFLICT DO NOTHING` cannot dedupe. Each batch is an `INSERT..SELECT`
with `NOT EXISTS` guards against both `sales.scout_candidates` and
`sales.leads`, making every batch idempotent and duplicate-safe.

See `.claude/skills/scout-import/SKILL.md` for the end-to-end session
workflow (collect → execute via MCP → verify).
