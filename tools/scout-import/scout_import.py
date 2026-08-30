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
  python3 scout_import.py ingest-wave <dir> [--min-fit N] [--out DIR]
      <dir> holds hunter wave outputs (tools/hunter/schemas/wave_output.schema.json);
      emits candidate batches PLUS wave_coverage.sql / wave_targets.sql /
      wave_negatives.sql / wave_roster_updates.sql and needs_review.json

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
    return dedupe(records), manifest


def dedupe(records):
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
    return out


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


def norm_query(q):
    """Normalize a search query for coverage matching: lowercase, collapse
    whitespace. Kept in lockstep with the backfill in hunt_coverage."""
    return re.sub(r"\s+", " ", str(q or "").strip()).lower()


def _payload(rows):
    return json.dumps(rows).replace("'", "''")


# Tier vocabulary and score bands. Agents drift on all three of these — waves
# w2026-08-30c/d/e produced integer tiers (2/3), person names with the org
# glued on ("Food Bank of North Alabama — Bobby Bozeman"), and 30 scores
# outside their tier band in a single wave. Enforce mechanically rather than
# hoping the prompt holds.
TIER_ALIASES = {1: "A", 2: "B", 3: "C", "1": "A", "2": "B", "3": "C",
                "a": "A", "b": "B", "c": "C"}
TIER_BANDS = {"A": (7, 10), "B": (4, 7), "C": (4, 6)}


def normalize_person(raw, target_org=None):
    """Coerce one wave person record into the tier/score/name contract.

    Returns (record, [notes]). Mutates nothing the caller still needs.
    """
    notes = []
    meta = raw.get("meta")
    if not isinstance(meta, dict):
        meta = {}
        raw["meta"] = meta

    tier = meta.get("tier")
    if tier in TIER_ALIASES:
        meta["tier"] = TIER_ALIASES[tier]
        notes.append(f"tier {tier!r} -> {meta['tier']}")
    tier = meta.get("tier")

    # An org-policy Tier A is weaker than a personal giving page: cap it.
    if tier == "A" and meta.get("evidence_basis") == "org_policy":
        if meta.get("confidence") not in ("medium", "low"):
            meta["confidence"] = "medium"
            notes.append("org_policy confidence -> medium")
        if isinstance(raw.get("fit_score"), int) and raw["fit_score"] > 7:
            raw["fit_score"] = 7
            notes.append("org_policy score -> 7")

    org = target_org or meta.get("target_org") or ""
    name = str(raw.get("org_name") or "").strip()
    for sep in (" \u2014 ", " - ", ": "):
        if org and name.startswith(org + sep):
            raw["org_name"] = name[len(org) + len(sep):].strip()
            notes.append("stripped org prefix from name")
            break

    lo, hi = TIER_BANDS.get(tier, (1, 10))
    score = raw.get("fit_score")
    if isinstance(score, int) and not (lo <= score <= hi):
        raw["fit_score"] = max(lo, min(hi, score))
        notes.append(f"score {score} -> {raw['fit_score']} (tier {tier} band)")

    return raw, notes


def ingest_wave(directory, min_fit, out_dir, batch_size):
    """Ingest hunter wave output (tools/hunter/schemas/wave_output.schema.json).

    Reads every *.json in `directory` that carries wave_id + people, then:
      * people[]         -> candidate import batches (same pipeline as collect)
      * coverage[]       -> wave_coverage.sql      (sales.hunt_coverage)
      * orgs_discovered[]-> wave_targets.sql       (sales.hunt_targets)
      * negatives[]      -> wave_negatives.sql     (sales.hunt_negatives)
      * roster_verdict   -> wave_roster_updates.sql (status + headcounts)
      * needs_review[]   -> needs_review.json      (verifier queue)

    All emitted SQL is idempotent: coverage/negatives ride ON CONFLICT DO
    NOTHING on their unique indexes; targets use NOT EXISTS guards; candidate
    batches keep their existing NOT EXISTS guards.
    """
    os.makedirs(out_dir, exist_ok=True)
    people, coverage, targets, negatives, review, verdicts = [], [], [], [], [], []
    normalized = []  # (file, name, what was coerced) — reported in the manifest
    manifest = []
    for path in sorted(glob(os.path.join(directory, "*.json"))):
        try:
            data = json.loads(open(path, encoding="utf-8", errors="replace").read())
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or "people" not in data or "wave_id" not in data:
            continue
        wave_id = str(data.get("wave_id") or "wave-unknown")
        agent = str(data.get("agent") or os.path.basename(path))

        kept = 0
        for raw in data.get("people") or []:
            if isinstance(raw, dict):
                raw.setdefault("org_type", "individual")
                raw.setdefault("source_query", f"hunter:{wave_id}:{agent}")
                raw, _fixes = normalize_person(raw, data.get("target_org"))
                normalized.extend((os.path.basename(path), raw.get("org_name"), n)
                                  for n in _fixes)
            rec = normalize(raw, path)
            if rec and rec["fit_score"] >= min_fit:
                people.append(rec)
                kept += 1

        for c in data.get("coverage") or []:
            if not isinstance(c, dict) or not str(c.get("value") or "").strip():
                continue
            kind = c.get("kind") if c.get("kind") in ("url", "query") else "url"
            value = norm_site(c["value"]) if kind == "url" else norm_query(c["value"])
            if not value:
                continue
            outcome = c.get("outcome")
            if outcome not in ("found_people", "no_people", "dead", "paywalled", "offtopic"):
                outcome = "no_people"
            coverage.append({"kind": kind, "value": value,
                             "domain": value.split("/")[0] if kind == "url" else None,
                             "outcome": outcome,
                             "people_found": int(c.get("people_found") or 0),
                             "wave_id": wave_id})

        for o in data.get("orgs_discovered") or []:
            if isinstance(o, dict) and str(o.get("org_name") or "").strip():
                faith = o.get("faith_orientation")
                targets.append({"org_name": str(o["org_name"]).strip(),
                                "website": norm_site(o.get("website")),
                                "org_type": o.get("org_type") or "agency",
                                "size_estimate": o.get("size_estimate"),
                                "tier_profile": o.get("tier_profile") or "A",
                                "headcount_est": o.get("headcount_est"),
                                "faith_orientation": faith if faith in ("christian", "other_faith", "secular") else None,
                                "crm_incumbent": o.get("crm_incumbent"),
                                "do_not_pursue": bool(o.get("do_not_pursue")),
                                "do_not_pursue_reason": o.get("do_not_pursue_reason") if o.get("do_not_pursue") else None,
                                "notes": o.get("evidence"),
                                "wave_id": wave_id})

        for n in data.get("negatives") or []:
            if isinstance(n, dict) and str(n.get("name") or "").strip() and n.get("reason_code"):
                negatives.append({"entity_kind": n.get("entity_kind") if n.get("entity_kind") in ("org", "person") else "org",
                                  "name": str(n["name"]).strip(),
                                  "website": norm_site(n.get("website")),
                                  "reason_code": str(n["reason_code"]),
                                  "detail": n.get("detail"),
                                  "wave_id": wave_id})

        for r in data.get("needs_review") or []:
            if isinstance(r, dict):
                r["_agent"], r["_wave_id"] = agent, wave_id
                review.append(r)

        verdict = str(data.get("roster_verdict") or "").strip()
        target_org = str(data.get("target_org") or "").strip()
        if verdict and target_org:
            verdicts.append({"org": target_org, "verdict": verdict})

        manifest.append({"file": path, "agent": agent, "people_kept": kept,
                         "coverage": len(data.get("coverage") or []),
                         "orgs": len(data.get("orgs_discovered") or []),
                         "verdict": verdict or None})

    people = dedupe(people)
    batches = emit_sql(people, out_dir, batch_size)

    if coverage:
        sql = (
            "with src as (select * from jsonb_to_recordset('" + _payload(coverage) + "'::jsonb)\n"
            "  as x(kind text, value text, domain text, outcome text, people_found int, wave_id text))\n"
            "insert into sales.hunt_coverage (kind, value, domain, outcome, people_found, wave_id)\n"
            "select kind, value, domain, outcome, people_found, wave_id from src\n"
            "on conflict do nothing;"
        )
        open(os.path.join(out_dir, "wave_coverage.sql"), "w").write(sql)

    if targets:
        sql = (
            "with src as (select * from jsonb_to_recordset('" + _payload(targets) + "'::jsonb)\n"
            "  as x(org_name text, website text, org_type text, size_estimate text,\n"
            "       tier_profile text, headcount_est int, faith_orientation text,\n"
            "       crm_incumbent text, do_not_pursue boolean, do_not_pursue_reason text,\n"
            "       notes text, wave_id text)),\n"
            # dedup within the batch: two agents in one wave can return the same
            # org under different websites, and NOT EXISTS below only sees rows
            # committed before this statement. Keep the richest row.
            "dedup as (select distinct on (lower(trim(org_name))) * from src\n"
            "  order by lower(trim(org_name)),\n"
            "           (website is not null) desc, (notes is not null) desc,\n"
            "           (headcount_est is not null) desc)\n"
            "insert into sales.hunt_targets\n"
            "  (org_name, website, org_type, size_estimate, tier_profile, priority,\n"
            "   discovered_by, headcount_est, faith_orientation, crm_incumbent,\n"
            "   do_not_pursue, do_not_pursue_reason, notes)\n"
            "select s.org_name, s.website, s.org_type, s.size_estimate, s.tier_profile, 4,\n"
            "       'wave:' || s.wave_id, s.headcount_est, s.faith_orientation, s.crm_incumbent,\n"
            "       coalesce(s.do_not_pursue, false), s.do_not_pursue_reason, s.notes\n"
            "from dedup s\n"
            "where not exists (select 1 from sales.hunt_targets t\n"
            "                  where lower(trim(t.org_name)) = lower(trim(s.org_name)))\n"
            "  and not exists (select 1 from sales.hunt_negatives n\n"
            "                  where n.entity_kind = 'org'\n"
            "                    and lower(trim(n.name)) = lower(trim(s.org_name)))\n"
            "on conflict do nothing;"
        )
        open(os.path.join(out_dir, "wave_targets.sql"), "w").write(sql)

    if negatives:
        sql = (
            "with src as (select * from jsonb_to_recordset('" + _payload(negatives) + "'::jsonb)\n"
            "  as x(entity_kind text, name text, website text, reason_code text, detail text, wave_id text))\n"
            "insert into sales.hunt_negatives (entity_kind, name, website, reason_code, detail, source)\n"
            "select entity_kind, name, website, reason_code, detail, 'agent:' || wave_id from src\n"
            "on conflict do nothing;"
        )
        open(os.path.join(out_dir, "wave_negatives.sql"), "w").write(sql)

    updates = []
    for v in verdicts:
        org = v["org"].replace("'", "''")
        verdict = v["verdict"]
        if verdict.startswith("rejected:"):
            code = verdict.split(":", 1)[1].replace("'", "''")
            updates.append(
                f"update sales.hunt_targets set roster_status='rejected', reject_reason='{code}',\n"
                f"  last_rostered_at=now() where lower(trim(org_name)) = lower('{org}');")
        elif verdict in ("rostered", "exhausted"):
            updates.append(
                f"update sales.hunt_targets set roster_status='{verdict}',\n"
                f"  last_rostered_at=now() where lower(trim(org_name)) = lower('{org}');")
    # Refresh headcounts from what actually landed in the queue + pipeline.
    updates.append(
        "update sales.hunt_targets t set headcount_found = c.n\n"
        "from (select lower(trim(meta->>'target_org')) as org, count(*) as n\n"
        "      from sales.scout_candidates\n"
        "      where meta ? 'target_org' and status <> 'rejected'\n"
        "      group by 1) c\n"
        "where lower(trim(t.org_name)) = c.org;")
    open(os.path.join(out_dir, "wave_roster_updates.sql"), "w").write("\n\n".join(updates))

    if review:
        json.dump(review, open(os.path.join(out_dir, "needs_review.json"), "w"), indent=2)

    return {"agents": manifest, "unique_people": len(people), "batches": batches,
            "normalizations": len(normalized),
            "normalization_detail": normalized[:40],
            "coverage_rows": len(coverage), "orgs_discovered": len(targets),
            "negatives": len(negatives), "needs_review": len(review),
            "roster_verdicts": len(verdicts), "out_dir": out_dir}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["collect", "report", "snapshot", "ingest-wave"])
    ap.add_argument("path", help="hunter-output directory (collect/report), "
                                 "or existing-contacts JSON file (snapshot)")
    ap.add_argument("--min-fit", type=int, default=6)
    ap.add_argument("--out", default="./scout_import_out")
    ap.add_argument("--batch-size", type=int, default=100)
    ap.add_argument("--limit", type=int, default=200,
                    help="snapshot: max domains to inline in the prompt snippet")
    args = ap.parse_args()

    if args.command == "ingest-wave":
        summary = ingest_wave(args.path, args.min_fit, args.out, args.batch_size)
        with open(os.path.join(args.out, "wave_manifest.json"), "w") as f:
            json.dump(summary, f, indent=2)
        json.dump(summary, sys.stdout, indent=2)
        print()
        return

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
