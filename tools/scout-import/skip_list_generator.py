#!/usr/bin/env python3
"""Skip list generator for DonorSend hunter operations.

Generates JSON skip lists (organization names and normalized URLs) from
existing scout_candidates and leads database records. These skip lists
prevent hunters from re-discovering prospects already in the CRM.

Integrates with export_existing.sql and scout_import.py.

Usage:
  # Generate skip lists from existing.json (exported from database)
  python3 skip_list_generator.py generate-from-json existing.json \\
    --org-names org_names.json --normalized-urls normalized_urls.json

  # Generate skip lists by running SQL queries directly against Supabase
  python3 skip_list_generator.py generate-direct \\
    --supabase-url https://your-project.supabase.co \\
    --supabase-key your-api-key \\
    --org-names org_names.json --normalized-urls normalized_urls.json

  # Validate existing skip list files
  python3 skip_list_generator.py validate org_names.json normalized_urls.json

  # Create a hunter prompt snippet from skip lists
  python3 skip_list_generator.py prompt org_names.json normalized_urls.json \\
    --limit 200 > hunter_skiplist.txt
"""

import argparse
import json
import os
import re
import sys
from typing import Dict, List, Optional, Tuple


def norm_site(w: Optional[str]) -> Optional[str]:
    """Normalize a website for equality matching.

    Drop scheme, leading www., and trailing slashes, lowercase.
    Returns None for empty/missing.

    Kept in lockstep with scout_import.py so Python and database dedup agree.
    """
    if not w:
        return None
    s = re.sub(r"^https?://", "", str(w).strip(), flags=re.I)
    s = re.sub(r"^www\.", "", s, flags=re.I)
    return s.rstrip("/").lower() or None


def extract_skip_lists(rows: List[Dict]) -> Tuple[List[str], List[str], Dict]:
    """Extract skip lists from database export rows.

    Args:
        rows: List of {"org_name": str, "website": str} dicts from export_existing.sql

    Returns:
        (org_names_list, normalized_urls_list, stats_dict)
    """
    org_names = set()
    normalized_urls = set()

    for row in rows:
        name = str(row.get("org_name") or "").strip()
        if name:
            org_names.add(name)

        site = norm_site(row.get("website"))
        if site:
            normalized_urls.add(site)

    stats = {
        "total_records": len(rows),
        "unique_org_names": len(org_names),
        "unique_normalized_urls": len(normalized_urls),
        "notes": "Extracted from sales.scout_candidates and sales.leads"
    }

    return sorted(org_names), sorted(normalized_urls), stats


def load_rows_from_json(path: str) -> List[Dict]:
    """Load rows from export_existing.sql JSON output.

    Accepts:
      - JSON array: [{"org_name": ..., "website": ...}, ...]
      - Object with rows key: {"rows": [...], ...}
      - Object with data key: {"data": [...], ...}
    """
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, list):
        return data

    for key in ("rows", "data", "result"):
        if isinstance(data, dict) and isinstance(data.get(key), list):
            return data[key]

    raise ValueError(f"{path}: expected JSON array or object with 'rows'/'data' key")


def write_skip_list(records: List[str], output_path: str, list_type: str,
                   total_count: int, extraction_date: Optional[str] = None) -> None:
    """Write a skip list JSON file.

    Args:
        records: Sorted list of unique values (org names or normalized URLs)
        output_path: Output file path
        list_type: "org_names" or "normalized_urls"
        total_count: Total records in source export
        extraction_date: ISO format date string (auto-generated if None)
    """
    if extraction_date is None:
        from datetime import datetime
        extraction_date = datetime.utcnow().isoformat() + "Z"

    payload = {
        "status": "ACTIVE",
        list_type: records,
        "metadata": {
            "total_count": total_count,
            "unique_count": len(records),
            "extraction_date": extraction_date,
            "normalization_applied": list_type == "normalized_urls",
            "note": "LIVE extraction from database - ready for agent deployment"
        }
    }

    if list_type == "org_names":
        payload["metadata"]["query"] = \
            "SELECT DISTINCT org_name FROM sales.scout_candidates WHERE org_name IS NOT NULL " + \
            "UNION SELECT DISTINCT org_name FROM sales.leads WHERE org_name IS NOT NULL"
    else:
        payload["metadata"]["query"] = \
            "SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) " + \
            "FROM sales.scout_candidates WHERE website IS NOT NULL " + \
            "UNION SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) " + \
            "FROM sales.leads WHERE website IS NOT NULL"
        payload["metadata"]["normalization_rule"] = \
            "LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', ''))"

    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(payload, f, indent=2)

    print(f"✓ Wrote {len(records)} unique {list_type} to {output_path}")


def generate_from_json(existing_json: str, org_names_out: str, urls_out: str) -> Dict:
    """Generate skip lists from export_existing.sql JSON export.

    Args:
        existing_json: Path to JSON file from export_existing.sql
        org_names_out: Output path for org_names skip list
        urls_out: Output path for normalized_urls skip list

    Returns:
        Summary stats dict
    """
    print(f"Loading existing records from {existing_json}...")
    rows = load_rows_from_json(existing_json)
    print(f"Loaded {len(rows)} records")

    org_names, normalized_urls, stats = extract_skip_lists(rows)

    print(f"Extracted: {len(org_names)} unique org names, {len(normalized_urls)} unique normalized URLs")

    write_skip_list(org_names, org_names_out, "org_names", len(rows))
    write_skip_list(normalized_urls, urls_out, "normalized_urls", len(rows))

    stats["org_names_output"] = org_names_out
    stats["normalized_urls_output"] = urls_out

    return stats


def generate_direct(supabase_url: str, supabase_key: str, org_names_out: str, urls_out: str) -> Dict:
    """Generate skip lists by querying Supabase directly.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase API key
        org_names_out: Output path for org_names skip list
        urls_out: Output path for normalized_urls skip list

    Returns:
        Summary stats dict
    """
    import urllib.request
    import urllib.parse

    def query_supabase(sql: str) -> List[Dict]:
        """Execute SQL against Supabase via REST API."""
        headers = {
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json"
        }

        body = json.dumps({"query": sql}).encode("utf-8")

        # Supabase SQL endpoint
        url = f"{supabase_url.rstrip('/')}/rest/v1/rpc/sql_query"

        try:
            req = urllib.request.Request(url, data=body, headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                return result if isinstance(result, list) else result.get("data", [])
        except Exception as e:
            raise RuntimeError(f"Supabase query failed: {e}")

    print("Querying Supabase for org_names...")
    org_query = (
        "SELECT DISTINCT org_name FROM sales.scout_candidates WHERE org_name IS NOT NULL "
        "UNION SELECT DISTINCT org_name FROM sales.leads WHERE org_name IS NOT NULL "
        "ORDER BY org_name"
    )
    org_rows = query_supabase(org_query)

    print("Querying Supabase for normalized_urls...")
    url_query = (
        "SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) as url "
        "FROM sales.scout_candidates WHERE website IS NOT NULL "
        "UNION SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) as url "
        "FROM sales.leads WHERE website IS NOT NULL "
        "ORDER BY url"
    )
    url_rows = query_supabase(url_query)

    org_names = [r.get("org_name") for r in org_rows if r.get("org_name")]
    normalized_urls = [r.get("url") for r in url_rows if r.get("url")]

    total_rows = len(org_rows) + len(url_rows)  # Approximate

    print(f"Extracted: {len(org_names)} unique org names, {len(normalized_urls)} unique normalized URLs")

    write_skip_list(org_names, org_names_out, "org_names", total_rows)
    write_skip_list(normalized_urls, urls_out, "normalized_urls", total_rows)

    return {
        "unique_org_names": len(org_names),
        "unique_normalized_urls": len(normalized_urls),
        "org_names_output": org_names_out,
        "normalized_urls_output": urls_out
    }


def validate_skip_lists(org_names_path: str, urls_path: str) -> Dict:
    """Validate skip list files.

    Args:
        org_names_path: Path to skip_list_org_names.json
        urls_path: Path to skip_list_normalized_urls.json

    Returns:
        Validation results dict
    """
    results = {"valid": True, "issues": []}

    for path, list_type in [(org_names_path, "org_names"), (urls_path, "normalized_urls")]:
        try:
            with open(path) as f:
                data = json.load(f)

            if not isinstance(data, dict):
                results["issues"].append(f"{path}: root is not an object")
                results["valid"] = False
                continue

            records = data.get(list_type)
            if not isinstance(records, list):
                results["issues"].append(f"{path}: {list_type} is not an array")
                results["valid"] = False
                continue

            if not records:
                results["issues"].append(f"{path}: {list_type} array is empty")
                results["valid"] = False
                continue

            # Sample validation
            for i, record in enumerate(records[:5]):
                if not isinstance(record, str):
                    results["issues"].append(f"{path}: {list_type}[{i}] is not a string")
                    results["valid"] = False
                    break

            meta = data.get("metadata", {})
            if meta.get("status") != "ACTIVE":
                results["issues"].append(f"{path}: metadata.status is not ACTIVE")
                results["valid"] = False

            print(f"✓ {path}: valid ({len(records)} records, "
                  f"last updated {meta.get('extraction_date', 'unknown')})")

        except FileNotFoundError:
            results["issues"].append(f"{path}: file not found")
            results["valid"] = False
        except json.JSONDecodeError as e:
            results["issues"].append(f"{path}: invalid JSON - {e}")
            results["valid"] = False

    return results


def generate_hunter_prompt(org_names_path: str, urls_path: str, limit: int = 200) -> str:
    """Generate a hunter prompt snippet from skip lists.

    Args:
        org_names_path: Path to skip_list_org_names.json
        urls_path: Path to skip_list_normalized_urls.json
        limit: Max domains to show in prompt

    Returns:
        Prompt snippet text
    """
    with open(org_names_path) as f:
        org_data = json.load(f)
    with open(urls_path) as f:
        url_data = json.load(f)

    org_names = org_data.get("org_names", [])
    normalized_urls = url_data.get("normalized_urls", [])

    # Extract domain hostnames
    domains = set()
    for url in normalized_urls:
        domain = url.split("/")[0]  # Get just the domain, not path
        domains.add(domain)

    domain_list = sorted(domains)
    shown = domain_list[:limit]

    header = (
        f"ALREADY IN THE DONORSEND CRM — do NOT return these; find NEW prospects.\n"
        f"The CRM already has {len(org_names)} contacts across {len(domain_list)} domains.\n"
        f"Known domains include:\n"
    )

    snippet = header + ", ".join(shown)

    if len(domain_list) > limit:
        snippet += f", …(+{len(domain_list) - limit} more)"

    snippet += (
        "\n\nIf a prospect's giving page or website is on one of these domains, "
        "assume we already have them unless it's a clearly different person."
    )

    return snippet


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = ap.add_subparsers(dest="command", required=True)

    # generate-from-json
    gen_json = subparsers.add_parser(
        "generate-from-json",
        help="Generate skip lists from export_existing.sql JSON export"
    )
    gen_json.add_argument("existing_json", help="JSON file from export_existing.sql")
    gen_json.add_argument("--org-names", default="skip_list_org_names.json",
                          help="Output path for org_names skip list")
    gen_json.add_argument("--normalized-urls", default="skip_list_normalized_urls.json",
                          help="Output path for normalized_urls skip list")
    gen_json.add_argument("--index", default="skip_list_index.json",
                          help="Also generate/update the index file")

    # generate-direct
    gen_direct = subparsers.add_parser(
        "generate-direct",
        help="Generate skip lists by querying Supabase directly"
    )
    gen_direct.add_argument("--supabase-url", required=True,
                            help="Supabase project URL")
    gen_direct.add_argument("--supabase-key", required=True,
                            help="Supabase API key")
    gen_direct.add_argument("--org-names", default="skip_list_org_names.json",
                            help="Output path for org_names skip list")
    gen_direct.add_argument("--normalized-urls", default="skip_list_normalized_urls.json",
                            help="Output path for normalized_urls skip list")
    gen_direct.add_argument("--index", default="skip_list_index.json",
                            help="Also generate/update the index file")

    # validate
    validate = subparsers.add_parser("validate", help="Validate skip list files")
    validate.add_argument("org_names", help="Path to skip_list_org_names.json")
    validate.add_argument("normalized_urls", help="Path to skip_list_normalized_urls.json")

    # prompt
    prompt = subparsers.add_parser("prompt", help="Generate hunter prompt snippet from skip lists")
    prompt.add_argument("org_names", help="Path to skip_list_org_names.json")
    prompt.add_argument("normalized_urls", help="Path to skip_list_normalized_urls.json")
    prompt.add_argument("--limit", type=int, default=200,
                        help="Max domains to show in prompt")

    args = ap.parse_args()

    if args.command == "generate-from-json":
        stats = generate_from_json(args.existing_json, args.org_names, args.normalized_urls)
        print("\n" + json.dumps(stats, indent=2))

    elif args.command == "generate-direct":
        stats = generate_direct(args.supabase_url, args.supabase_key,
                               args.org_names, args.normalized_urls)
        print("\n" + json.dumps(stats, indent=2))

    elif args.command == "validate":
        results = validate_skip_lists(args.org_names, args.normalized_urls)
        if results["valid"]:
            print("\n✓ All skip lists are valid and ready to use")
        else:
            print("\n✗ Validation failed:")
            for issue in results["issues"]:
                print(f"  - {issue}")
            sys.exit(1)

    elif args.command == "prompt":
        snippet = generate_hunter_prompt(args.org_names, args.normalized_urls, args.limit)
        print(snippet)


if __name__ == "__main__":
    main()
