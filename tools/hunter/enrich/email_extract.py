#!/usr/bin/env python3
"""Extract published per-person emails from already-collected person pages.

This is an extraction pass, not a hunt. Every person in the worklist is
already an approved candidate with a live lead and a stored per-person URL.
The only thing missing is the email that the page itself publishes.

Two phases, deliberately split so the parse half can be tested and reviewed
without network access:

  fetch  worklist.csv -> html/      needs egress to the agency domain
  emit   html/        -> out.sql    pure local parse, no network

Usage:
  python3 email_extract.py fetch --worklist worklist.csv --html-dir html/
                                 [--rate 1.0] [--limit N] [--resume]
  python3 email_extract.py emit  --worklist worklist.csv --html-dir html/
                                 --out out.sql [--tag focus-2026-09-21]

Design rules this tool enforces, each earned from a prior mistake:

  * Only addresses the page actually publishes are emitted. This tool never
    infers an address from a name pattern. The CRM already holds 300 inferred
    addresses and none of them is verified; adding more guesses would deepen
    that hole, not fill it.
  * An address that shows up on many different people's pages is the agency
    switchboard, not that person's address. Anything appearing on more than
    --shared-max pages is demoted to email_kind 'role' or 'org' so it can
    never be mistaken for a personal contact.
  * Cloudflare email obfuscation is decoded rather than stored. A page under
    Cloudflare protection renders the literal text "[email protected]" and
    hides the real address in a data-cfemail hex blob. Storing the placeholder
    would look like success and be worthless.
  * Emitted SQL writes BOTH scout_candidate_id and lead_id on every contact
    row. Only 2,327 of 7,302 existing contact rows carry the candidate key,
    which is why "do we already have this email" has been unreliable.
"""

import argparse
import csv
import html
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from urllib.parse import urlparse

# --------------------------------------------------------------------------
# extraction
# --------------------------------------------------------------------------

EMAIL_RE = re.compile(
    r"[A-Za-z0-9._%+-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+"
)
MAILTO_RE = re.compile(r"""mailto:([^"'?>\s]+)""", re.I)
CFEMAIL_RE = re.compile(r"""data-cfemail\s*=\s*["']([0-9a-fA-F]+)["']""")

# Local parts that are never an individual's personal address.
ROLE_LOCALS = {
    "info", "contact", "support", "help", "admin", "office", "mail", "email",
    "giving", "give", "donate", "donations", "gifts", "development",
    "missions", "mission", "advancement", "stewardship", "partners",
    "hello", "inquiries", "enquiries", "webmaster", "postmaster", "noreply",
    "no-reply", "donotreply", "privacy", "legal", "press", "media", "jobs",
    "careers", "hr", "billing", "accounting", "finance", "receipts",
    # Function mailboxes common on agency person pages specifically.
    "team", "staff", "missionary", "missionaries", "partner", "prayer",
    "connect", "serve", "sendme", "generosity", "donorcare", "donorservices",
}

# Never store these: asset filenames and obfuscation placeholders that the
# naive regex happily matches.
JUNK_SUFFIXES = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp",
                 ".css", ".js", ".ico", ".woff", ".woff2", ".ttf")
PLACEHOLDER_RE = re.compile(r"email.{0,3}protected", re.I)


def decode_cfemail(hexblob):
    """Decode a Cloudflare data-cfemail blob.

    The first byte is the XOR key; each remaining byte is one character of
    the address XORed with it. Returns None if the blob is malformed.
    """
    try:
        data = bytes.fromhex(hexblob)
    except ValueError:
        return None
    if len(data) < 2:
        return None
    key = data[0]
    try:
        out = "".join(chr(b ^ key) for b in data[1:])
    except ValueError:
        return None
    return out if "@" in out else None


def is_junk(addr):
    low = addr.lower()
    if PLACEHOLDER_RE.search(low):
        return True
    if low.endswith(JUNK_SUFFIXES):
        return True
    if low.count("@") != 1:
        return True
    local, _, domain = low.partition("@")
    if not local or not domain or "." not in domain:
        return True
    # A bare version-number-looking domain is a false positive from inline JS.
    if re.fullmatch(r"[\d.]+", domain):
        return True
    return False


def extract_emails(page_html):
    """Return the ordered, de-duplicated addresses a page publishes."""
    found = []

    def add(a):
        if not a:
            return
        a = html.unescape(a).strip().strip(".,;:<>()[]'\"")
        if not a or is_junk(a):
            return
        if a.lower() not in [x.lower() for x in found]:
            found.append(a)

    for blob in CFEMAIL_RE.findall(page_html):
        add(decode_cfemail(blob))
    for m in MAILTO_RE.findall(page_html):
        add(m)
    # Strip script/style before the loose text sweep: inline JS is the main
    # source of junk matches.
    stripped = re.sub(r"<(script|style)\b.*?</\1>", " ", page_html,
                      flags=re.I | re.S)
    stripped = re.sub(r"<[^>]+>", " ", stripped)
    for m in EMAIL_RE.findall(stripped):
        add(m)
    return found


def classify(addr, person_name, shared_count, shared_max):
    """Decide email_kind for an address found on one person's page.

    'direct'  the page publishes this address for this person
    'role'    a function mailbox (giving@, info@) rather than a person
    'org'     a personal-looking address that nonetheless appears on so many
              different pages that it cannot belong to any one of them
    """
    local = addr.split("@", 1)[0].lower()
    base = re.split(r"[._+-]", local)[0]
    if local in ROLE_LOCALS or base in ROLE_LOCALS:
        return "role"
    if shared_count > shared_max:
        return "org"
    return "direct"


def name_overlap(addr, person_name):
    """True when the address local part contains a piece of the person's name.

    Used only as a confidence signal, never as a filter: plenty of genuine
    addresses are initials or a nickname.
    """
    local = re.sub(r"[^a-z]", " ", addr.split("@", 1)[0].lower())
    parts = {p for p in local.split() if len(p) >= 3}
    names = {p.lower() for p in re.findall(r"[A-Za-z]{3,}", person_name or "")}
    return bool(parts & names)


# --------------------------------------------------------------------------
# io
# --------------------------------------------------------------------------

def read_worklist(path):
    with open(path, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    required = {"scout_candidate_id", "lead_id", "person_name", "url"}
    if rows and not required.issubset(rows[0].keys()):
        missing = required - set(rows[0].keys())
        sys.exit("worklist is missing column(s): %s" % ", ".join(sorted(missing)))
    return rows


def html_path(html_dir, scout_candidate_id):
    return os.path.join(html_dir, "%s.html" % scout_candidate_id)


def cmd_fetch(args):
    import urllib.error
    import urllib.request

    rows = read_worklist(args.worklist)
    if args.limit:
        rows = rows[: args.limit]
    os.makedirs(args.html_dir, exist_ok=True)

    ok = skipped = failed = 0
    log = []
    for i, row in enumerate(rows, 1):
        dest = html_path(args.html_dir, row["scout_candidate_id"])
        if args.resume and os.path.exists(dest) and os.path.getsize(dest) > 0:
            skipped += 1
            continue
        req = urllib.request.Request(
            row["url"],
            headers={"User-Agent": args.user_agent, "Accept": "text/html"},
        )
        try:
            with urllib.request.urlopen(req, timeout=args.timeout) as resp:
                body = resp.read().decode("utf-8", "replace")
            with open(dest, "w", encoding="utf-8") as fh:
                fh.write(body)
            ok += 1
        except Exception as exc:  # noqa: BLE001 - log and continue
            failed += 1
            log.append({"url": row["url"], "error": "%s: %s"
                        % (type(exc).__name__, exc)})
        if i % 25 == 0:
            print("  %d/%d  ok=%d skipped=%d failed=%d"
                  % (i, len(rows), ok, skipped, failed), file=sys.stderr)
        time.sleep(args.rate)

    if log:
        errp = os.path.join(args.html_dir, "_fetch_errors.json")
        with open(errp, "w", encoding="utf-8") as fh:
            json.dump(log, fh, indent=2)
        print("fetch errors written to %s" % errp, file=sys.stderr)
    print("fetched ok=%d skipped=%d failed=%d" % (ok, skipped, failed))


def sql_str(v):
    if v is None:
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def cmd_emit(args):
    rows = read_worklist(args.worklist)

    # Pass 1: parse every saved page.
    per_person = {}
    missing = 0
    for row in rows:
        p = html_path(args.html_dir, row["scout_candidate_id"])
        if not os.path.exists(p):
            missing += 1
            continue
        with open(p, encoding="utf-8", errors="replace") as fh:
            body = fh.read()
        per_person[row["scout_candidate_id"]] = (row, extract_emails(body))

    # Pass 2: how many distinct people publish each address? An address on
    # many pages is the agency switchboard.
    freq = Counter()
    for _row, addrs in per_person.values():
        for a in {x.lower() for x in addrs}:
            freq[a] += 1

    emitted, stats = [], defaultdict(int)
    for scout_id, (row, addrs) in per_person.items():
        if not addrs:
            stats["no_email_on_page"] += 1
            continue
        best = None
        for a in addrs:
            kind = classify(a, row["person_name"], freq[a.lower()],
                            args.shared_max)
            cand = (kind, a, name_overlap(a, row["person_name"]))
            order = {"direct": 0, "role": 1, "org": 2}
            if best is None or (order[kind], not cand[2]) < (order[best[0]], not best[2]):
                best = cand
        kind, addr, overlap = best
        stats[kind] += 1
        confidence = 9 if (kind == "direct" and overlap) else (
            7 if kind == "direct" else 4)
        emitted.append({
            "scout_candidate_id": scout_id,
            "lead_id": row["lead_id"],
            "name": row["person_name"],
            "email": addr,
            "email_kind": kind,
            "source_url": row["url"],
            "confidence": confidence,
            "shared_on_pages": freq[addr.lower()],
        })

    tag = args.tag
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("-- Email extraction: %s\n" % tag)
        fh.write("-- worklist rows: %d   pages parsed: %d   missing html: %d\n"
                 % (len(rows), len(per_person), missing))
        fh.write("-- emitted: %d  (direct=%d role=%d org=%d)   "
                 "pages with no published email: %d\n"
                 % (len(emitted), stats["direct"], stats["role"],
                    stats["org"], stats["no_email_on_page"]))
        fh.write("--\n-- Every address below was read off the page. Nothing "
                 "here is inferred from a name pattern.\n")
        fh.write("-- 'org' means the address appeared on more than %d "
                 "different people's pages.\n\n" % args.shared_max)
        fh.write("set local statement_timeout = '50s';\n\nbegin;\n\n")
        fh.write("create table if not exists sales.email_extract_%s (\n"
                 "  scout_candidate_id uuid, lead_id uuid, email text,\n"
                 "  email_kind text, source_url text, confidence int,\n"
                 "  shared_on_pages int, applied_at timestamptz default now()\n"
                 ");\n\n" % re.sub(r"[^a-z0-9_]", "_", tag.lower()))

        for e in emitted:
            fh.write(
                "insert into sales.email_extract_%s\n"
                "  (scout_candidate_id, lead_id, email, email_kind, "
                "source_url, confidence, shared_on_pages)\n"
                "values (%s, %s, %s, %s, %s, %d, %d);\n"
                % (re.sub(r"[^a-z0-9_]", "_", tag.lower()),
                   sql_str(e["scout_candidate_id"]), sql_str(e["lead_id"]),
                   sql_str(e["email"]), sql_str(e["email_kind"]),
                   sql_str(e["source_url"]), e["confidence"],
                   e["shared_on_pages"]))

        fh.write("""
-- Upsert into sales.contacts. Both keys are written on every row so the
-- next holdings check can be keyed on either one.
insert into sales.contacts
  (scout_candidate_id, lead_id, name, email, email_kind, source_url,
   confidence, verified, enriched_at, notes, meta)
select e.scout_candidate_id, e.lead_id, c.org_name, e.email, e.email_kind,
       e.source_url, e.confidence, false, now(),
       'email read from the person page on %(tag)s',
       jsonb_build_object('email_provenance', 'published',
                          'extract_tag', '%(tag)s',
                          'shared_on_pages', e.shared_on_pages)
from sales.email_extract_%(slug)s e
join sales.scout_candidates c on c.id = e.scout_candidate_id
where not exists (
  select 1 from sales.contacts x
  where (x.scout_candidate_id = e.scout_candidate_id or x.lead_id = e.lead_id)
    and lower(coalesce(x.email,'')) = lower(e.email)
);

-- Backfill the candidate key on contact rows that matched by lead only.
update sales.contacts x
   set scout_candidate_id = e.scout_candidate_id
  from sales.email_extract_%(slug)s e
 where x.lead_id = e.lead_id
   and x.scout_candidate_id is null
   and lower(coalesce(x.email,'')) = lower(e.email);

commit;

-- Verify before trusting the run:
--   select email_kind, count(*), count(distinct email)
--     from sales.email_extract_%(slug)s group by 1 order by 1;
--   select email, count(*) n from sales.email_extract_%(slug)s
--    group by 1 having count(*) > 1 order by n desc limit 20;
""" % {"tag": tag, "slug": re.sub(r"[^a-z0-9_]", "_", tag.lower())})

    print("worklist=%d parsed=%d missing_html=%d" % (len(rows), len(per_person), missing))
    print("emitted=%d  direct=%d role=%d org=%d  no_email_on_page=%d"
          % (len(emitted), stats["direct"], stats["role"], stats["org"],
             stats["no_email_on_page"]))
    print("sql -> %s" % args.out)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("fetch", help="download the person pages")
    f.add_argument("--worklist", required=True)
    f.add_argument("--html-dir", required=True)
    f.add_argument("--rate", type=float, default=1.0,
                   help="seconds to sleep between requests (default 1.0)")
    f.add_argument("--timeout", type=float, default=30.0)
    f.add_argument("--limit", type=int)
    f.add_argument("--resume", action="store_true",
                   help="skip pages already saved")
    f.add_argument("--user-agent",
                   default="DonorSend research (contact: see donorsend.com)")
    f.set_defaults(func=cmd_fetch)

    e = sub.add_parser("emit", help="parse saved pages and emit SQL")
    e.add_argument("--worklist", required=True)
    e.add_argument("--html-dir", required=True)
    e.add_argument("--out", required=True)
    e.add_argument("--tag", default="extract")
    e.add_argument("--shared-max", type=int, default=3,
                   help="an address on more than this many different people's "
                        "pages is treated as an org address (default 3)")
    e.set_defaults(func=cmd_emit)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
