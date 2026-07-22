#!/usr/bin/env python3
"""Scout import pipeline for DonorSend hunter output.

Hunters (research subagents) produce candidate files in several shapes:
  * SQL files using jsonb_to_recordset('[...]') with short keys
      n=org_name, t=org_type, w=website, s=summary, f=fit_score,
      r=fit_reason, q=source_query, m=meta
  * SQL files using jsonb_to_recordset('[...]') with long keys
      (org_name, org_type, website, summary, fit_score, ...)
  * Plain JSON files: an array of records in either key style

This tool collects them, normalizes to the sales.scout_candidates schema,
dedupes within the batch (keeping the highest fit score per name), and
emits batch SQL whose inserts self-dedupe against the live table with
NOT EXISTS checks on lower(trim(org_name)) vs both sales.scout_candidates
and sales.leads. ON CONFLICT is useless here (no unique constraint on
org_name), which is why the guards are in the SELECT.

Usage:
  python3 scout_import.py collect <dir> [--min-fit N] [--out DIR] [--batch-size N]
  python3 scout_import.py report  <dir> [--min-fit N]

Outputs (in --out, default ./scout_import_out):
  import_batch_<i>.sql   one INSERT..SELECT per batch, safe to re-run
  verify.sql             post-import verification queries
  manifest.json          what was collected, from where, and counts
"""

import argparse
import json
import os
import re
import sys
from glob import glob

SHORT_KEYS = {"n": "org_name", "t": "org_type", "w": "website", "s": "summary",
              "f": "fit_score", "r": "fit_reason", "q": "source_query", "m": "meta"}
CANON_KEYS = ["org_name", "org_type", "website", "city", "state", "summary",
              "fit_score", "fit_reason", "source_query", "meta"]
# sales.scout_candidates.status check constraint allows only these:
VALID_STATUS = {"pending", "approved", "rejected", "skipped"}


def extract_json_arrays_from_sql(text):
    """Yield every jsonb_to_recordset('[...]') payload in a SQL file."""
    marker = "jsonb_to_recordset('"
    pos = 0
    while True:
        start = text.find(marker, pos)
        if start == -1:
            return
        start += len(marker)
        end = text.find("'::jsonb", start)
        if end == -1:
            return
        payload = text[start:end].replace("''", "'")
        try:
            arr = json.loads(payload)
            if isinstance(arr, list):
                yield arr
        except json.JSONDecodeError:
            pass
        pos = end


def normalize(record, source_file):
    """Map a raw hunter record (short or long keys) to canonical shape.

    Returns None for records that don't carry the minimum viable fields.
    """
    if not isinstance(record, dict):
        return None
    rec = {}
    for k, v in record.items():
        key = SHORT_KEYS.get(k, k)
        rec[key] = v

    name = str(rec.get("org_name") or "").strip()
    if not name:
        return None

    try:
        fit = int(rec.get("fit_score"))
    except (TypeError, ValueError):
        return None
    fit = max(1, min(10, fit))

    org_type = str(rec.get("org_type") or "").strip().lower()
    if org_type not in ("individual", "organization", "ministry", "church",
                        "nonprofit", "missionary", "other"):
        org_type = "ministry"

    website = str(rec.get("website") or "").strip()
    website = re.sub(r"^https?://", "", website).rstrip("/") or None

    meta = rec.get("meta")
    if not isinstance(meta, dict):
        meta = {}
    meta.setdefault("import_source", os.path.basename(source_file))

    return {
        "org_name": name,
        "org_type": org_type,
        "website": website,
        "city": (str(rec.get("city")).strip() or None) if rec.get("city") else None,
        "state": (str(rec.get("state")).strip()[:2] or None) if rec.get("state") else None,
        "summary": str(rec.get("summary") or "").strip() or None,
        "fit_score": fit,
        "fit_reason": str(rec.get("fit_reason") or "").strip() or None,
        "source_query": str(rec.get("source_query") or "hunter:import").strip(),
        "meta": meta,
    }


def collect(directory, min_fit):
    """Gather and normalize every hunter record under directory."""
    records, manifest = [], []
    paths = sorted(glob(os.path.join(directory, "**", "*"), recursive=True))
    for path in paths:
        if not os.path.isfile(path):
            continue
        ext = os.path.splitext(path)[1].lower()
        raw = []
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if ext == ".sql":
            for arr in extract_json_arrays_from_sql(text):
                raw.extend(arr)
        elif ext == ".json":
            try:
                data = json.loads(text)
                if isinstance(data, list):
                    raw = data
                elif isinstance(data, dict) and isinstance(data.get("candidates"), list):
                    raw = data["candidates"]
            except json.JSONDecodeError:
                pass
        if not raw:
            continue
        kept = [r for r in (normalize(x, path) for x in raw) if r and r["fit_score"] >= min_fit]
        if kept:
            records.extend(kept)
            manifest.append({"file": path, "raw": len(raw), "kept": len(kept)})
    # Within-batch dedupe by name, keep the highest fit score.
    best = {}
    for r in records:
        key = r["org_name"].lower().strip()
        if key not in best or r["fit_score"] > best[key]["fit_score"]:
            best[key] = r
    return list(best.values()), manifest


def emit_sql(records, out_dir, batch_size):
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for i in range(0, len(records), batch_size):
        chunk = records[i:i + batch_size]
        payload = json.dumps(chunk).replace("'", "''")
        sql = (
            "with src as (select * from jsonb_to_recordset('" + payload + "'::jsonb)\n"
            "  as x(org_name text, org_type text, website text, city text, state text,\n"
            "       summary text, fit_score int, fit_reason text, source_query text, meta jsonb))\n"
            "insert into sales.scout_candidates\n"
            "  (org_name, org_type, website, city, state, summary,\n"
            "   fit_score, fit_reason, source_query, status, meta)\n"
            "select s.org_name, s.org_type, s.website, s.city, s.state, s.summary,\n"
            "       s.fit_score, s.fit_reason, s.source_query, 'pending', coalesce(s.meta, '{}'::jsonb)\n"
            "from src s\n"
            "where not exists (select 1 from sales.scout_candidates c\n"
            "                  where lower(trim(c.org_name)) = lower(trim(s.org_name)))\n"
            "  and not exists (select 1 from sales.leads l\n"
            "                  where lower(trim(l.org_name)) = lower(trim(s.org_name)));"
        )
        path = os.path.join(out_dir, f"import_batch_{i // batch_size}.sql")
        open(path, "w").write(sql)
        files.append({"file": path, "records": len(chunk), "kb": round(len(sql) / 1024)})

    verify = """-- Post-import verification for sales.scout_candidates
select count(*) as total,
       count(*) filter (where fit_score >= 8) as fit8plus,
       count(*) filter (where fit_score between 6 and 7) as fit67
from sales.scout_candidates;

select fit_score, count(*) from sales.scout_candidates
group by fit_score order by fit_score desc nulls last;

-- Should return 0 rows worth of duplicates:
select count(*) as duplicate_names from (
  select lower(trim(org_name)) from sales.scout_candidates
  group by 1 having count(*) > 1
) d;

-- Should be 0 (status check constraint sanity):
select count(*) as bad_status from sales.scout_candidates
where status not in ('pending','approved','rejected','skipped');

select org_name, fit_score, website, created_at
from sales.scout_candidates order by created_at desc limit 5;
"""
    open(os.path.join(out_dir, "verify.sql"), "w").write(verify)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["collect", "report"])
    ap.add_argument("directory", help="directory containing hunter output files")
    ap.add_argument("--min-fit", type=int, default=6)
    ap.add_argument("--out", default="./scout_import_out")
    ap.add_argument("--batch-size", type=int, default=100)
    args = ap.parse_args()

    records, manifest = collect(args.directory, args.min_fit)
    dist = {}
    for r in records:
        dist[r["fit_score"]] = dist.get(r["fit_score"], 0) + 1

    summary = {
        "sources": manifest,
        "unique_records": len(records),
        "min_fit": args.min_fit,
        "fit_distribution": {str(k): dist[k] for k in sorted(dist, reverse=True)},
    }

    if args.command == "collect":
        summary["batches"] = emit_sql(records, args.out, args.batch_size)
        with open(os.path.join(args.out, "manifest.json"), "w") as f:
            json.dump(summary, f, indent=2)

    json.dump(summary if args.command == "report" else {
        "unique_records": summary["unique_records"],
        "fit_distribution": summary["fit_distribution"],
        "batches": summary.get("batches", []),
        "out_dir": args.out,
    }, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
