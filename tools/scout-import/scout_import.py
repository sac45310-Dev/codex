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


def norm_site(w):
    """Normalize a website for equality matching: drop scheme, leading www.,
    and trailing slashes, lowercase. Returns None for empty/missing.

    Kept deliberately in lockstep with the SQL guard in emit_sql() so the
    Python within-batch dedup and the database-side dedup agree on what
    counts as 'the same site'.
    """
    if not w:
        return None
    s = re.sub(r"^https?://", "", str(w).strip(), flags=re.I)
    s = re.sub(r"^www\.", "", s, flags=re.I)
    return s.rstrip("/").lower() or None


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
    # Within-batch dedupe, keeping the highest fit score at each step.
    # Pass 1: by normalized org name.
    by_name = {}
    for r in records:
        key = r["org_name"].lower().strip()
        if key not in by_name or r["fit_score"] > by_name[key]["fit_score"]:
            by_name[key] = r
    # Pass 2: by normalized website — collapses the same person found under
    # slightly different name spellings but a shared giving/ministry URL.
    # BUT a URL shared by 3+ name-distinct records is almost certainly a
    # roster/directory/platform page (e.g. an agency deputation list), not
    # one person's page — collapsing those would delete real distinct leads,
    # so we only treat a URL as an identity key when at most 2 records carry
    # it. Records without a website, or on a shared URL, pass through intact.
    site_freq = {}
    for r in by_name.values():
        site = norm_site(r["website"])
        if site:
            site_freq[site] = site_freq.get(site, 0) + 1
    by_site, out = {}, []
    for r in by_name.values():
        site = norm_site(r["website"])
        if site is None or site_freq[site] >= 3:
            out.append(r)
        elif site not in by_site or r["fit_score"] > by_site[site]["fit_score"]:
            by_site[site] = r
    out.extend(by_site.values())
    return out, manifest


def emit_sql(records, out_dir, batch_size):
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for i in range(0, len(records), batch_size):
        chunk = records[i:i + batch_size]
        payload = json.dumps(chunk).replace("'", "''")
        # normhost(x): strip scheme, leading www., trailing slashes, lowercase
        # — kept identical to norm_site() in Python so both sides agree.
        normhost = "rtrim(lower(regexp_replace({col}, '^https?://(www\\.)?', '', 'i')), '/')"
        sql = (
            "with src as (select * from jsonb_to_recordset('" + payload + "'::jsonb)\n"
            "  as x(org_name text, org_type text, website text, city text, state text,\n"
            "       summary text, fit_score int, fit_reason text, source_query text, meta jsonb)),\n"
            "-- Count how many existing rows (queue + pipeline) share each URL.\n"
            "-- A URL on exactly one row is a person-specific page safe to dedup\n"
            "-- against; a URL shared by many is a roster/platform page and must\n"
            "-- NOT cause a skip, or we'd drop distinct people who list it.\n"
            "existing_sites as (\n"
            "  select site, count(*) as n from (\n"
            "    select " + normhost.format(col="website") + " as site\n"
            "      from sales.scout_candidates where website is not null and btrim(website) <> ''\n"
            "    union all\n"
            "    select " + normhost.format(col="website") + " as site\n"
            "      from sales.leads where website is not null and btrim(website) <> ''\n"
            "  ) w group by site)\n"
            "insert into sales.scout_candidates\n"
            "  (org_name, org_type, website, city, state, summary,\n"
            "   fit_score, fit_reason, source_query, status, meta)\n"
            "select s.org_name, s.org_type, s.website, s.city, s.state, s.summary,\n"
            "       s.fit_score, s.fit_reason, s.source_query, 'pending', coalesce(s.meta, '{}'::jsonb)\n"
            "from src s\n"
            "where not exists (select 1 from sales.scout_candidates c\n"
            "                  where lower(trim(c.org_name)) = lower(trim(s.org_name)))\n"
            "  and not exists (select 1 from sales.leads l\n"
            "                  where lower(trim(l.org_name)) = lower(trim(s.org_name)))\n"
            "  and not exists (select 1 from existing_sites es\n"
            "                  where s.website is not null and btrim(s.website) <> ''\n"
            "                    and es.n = 1\n"
            "                    and es.site = " + normhost.format(col="s.website") + ");"
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


def build_snapshot(rows, limit):
    """Turn a live-DB export (rows of {org_name, website}) into a skip-list
    for hunter prompts, so hunters don't burn time re-finding contacts the
    CRM already has. Import-time dedup remains the real guard; this just
    reduces wasted searches.

    `rows` is the JSON array returned by export_existing.sql. Returns
    (prompt_snippet_text, stats).
    """
    domains, names = {}, []
    for row in rows:
        name = str(row.get("org_name") or "").strip()
        if name:
            names.append(name)
        site = norm_site(row.get("website"))
        if site:
            # keep the registrable-ish host (strip path) for compactness
            domains[site.split("/")[0]] = True
    domain_list = sorted(domains)
    shown = domain_list[:limit]
    header = (
        "ALREADY IN THE DONORSEND CRM — do NOT return these; find NEW "
        f"prospects. The CRM already has {len(names)} contacts across "
        f"{len(domain_list)} domains. Known domains include:\n"
    )
    snippet = header + ", ".join(shown)
    if len(domain_list) > limit:
        snippet += f", …(+{len(domain_list) - limit} more)"
    snippet += (
        "\nIf a prospect's giving page or site is on one of these domains, "
        "assume we already have them unless it's a clearly different person."
    )
    return snippet, {"known_contacts": len(names),
                     "known_domains": len(domain_list),
                     "domains_shown": len(shown)}


def _load_rows(path):
    """Read export_existing.sql output. Accepts a JSON array, or the
    {rows:[...]}/{data:[...]} wrappers some SQL runners emit."""
    data = json.loads(open(path, encoding="utf-8").read())
    if isinstance(data, list):
        return data
    for key in ("rows", "data", "result"):
        if isinstance(data, dict) and isinstance(data.get(key), list):
            return data[key]
    raise SystemExit(f"{path}: expected a JSON array of {{org_name, website}} rows")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["collect", "report", "snapshot"])
    ap.add_argument("path", help="hunter-output directory (collect/report), "
                                 "or existing-contacts JSON file (snapshot)")
    ap.add_argument("--min-fit", type=int, default=6)
    ap.add_argument("--out", default="./scout_import_out")
    ap.add_argument("--batch-size", type=int, default=100)
    ap.add_argument("--limit", type=int, default=200,
                    help="snapshot: max domains to inline in the prompt snippet")
    args = ap.parse_args()

    if args.command == "snapshot":
        snippet, stats = build_snapshot(_load_rows(args.path), args.limit)
        os.makedirs(args.out, exist_ok=True)
        snip_path = os.path.join(args.out, "hunter_skiplist.txt")
        open(snip_path, "w").write(snippet + "\n")
        stats["skiplist_file"] = snip_path
        json.dump(stats, sys.stdout, indent=2)
        print()
        return

    records, manifest = collect(args.path, args.min_fit)
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
