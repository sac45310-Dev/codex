import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Per-lead web tracking endpoint. Two routes, both public by design and
// intended to sit behind donorsend.app rewrites:
//
//   GET  /r/<token>   -> record the click, drop a first-party cookie,
//                        302 to the destination path on donorsend.app
//   POST /track       -> record a page view / download for the visitor
//                        identified by that cookie
//
// verify_jwt is OFF: these are hit by ordinary browsers with no session.
// Authorization comes from the token itself, which is unguessable (~122 bits)
// and rate limited to 120 hits/hour per link inside sales_track_visit.
//
// The cookie is scoped to .donorsend.app so the marketing site can keep
// attributing page views after the redirect. It is HttpOnly: /track reads it
// from the request header server-side, so no page script ever needs it, and
// XSS on the site cannot exfiltrate whose token it is.

const SITE = "https://donorsend.app";
const COOKIE = "ds_visitor";
const COOKIE_MAX_AGE = 60 * 60 * 24 * 400; // ~13 months

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function rpc(fn: string, body: unknown) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) return null;
  return await res.json().catch(() => null);
}

// Only the browser family/OS — the full UA string is a fingerprinting surface.
function uaFamily(ua: string | null): string {
  if (!ua) return "";
  const browser = /Edg\//.test(ua)
    ? "Edge"
    : /OPR\//.test(ua)
    ? "Opera"
    : /Chrome\//.test(ua)
    ? "Chrome"
    : /Safari\//.test(ua)
    ? "Safari"
    : /Firefox\//.test(ua)
    ? "Firefox"
    : "Other";
  const os = /iPhone|iPad|iOS/.test(ua)
    ? "iOS"
    : /Android/.test(ua)
    ? "Android"
    : /Mac OS X/.test(ua)
    ? "macOS"
    : /Windows/.test(ua)
    ? "Windows"
    : /Linux/.test(ua)
    ? "Linux"
    : "Other";
  return `${browser}/${os}`;
}

function readCookie(req: Request, name: string): string | null {
  const raw = req.headers.get("cookie");
  if (!raw) return null;
  for (const part of raw.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === name) return decodeURIComponent(v.join("="));
  }
  return null;
}

// dest comes from sales.links, where sales_create_link already constrains it
// to a path. Re-check here so a bad row can never turn this into an open
// redirect: anything not starting with a single "/" falls back to the root.
function safePath(dest: unknown): string {
  const p = typeof dest === "string" ? dest : "/";
  return /^\/[A-Za-z0-9_\/.\-?=&%]*$/.test(p) && !p.startsWith("//") ? p : "/";
}

function tokenFrom(url: URL): string | null {
  const q = url.searchParams.get("t");
  if (q) return q;
  // .../r/<token>  (also tolerates the function being called at its own path)
  const segs = url.pathname.split("/").filter(Boolean);
  const i = segs.indexOf("r");
  if (i >= 0 && segs[i + 1]) return segs[i + 1];
  return segs.length ? segs[segs.length - 1] : null;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const country = req.headers.get("cf-ipcountry") ??
    req.headers.get("x-vercel-ip-country") ?? "";
  const ua = uaFamily(req.headers.get("user-agent"));

  // ---- POST /track : page views and downloads after the click ----
  if (req.method === "POST") {
    const token = readCookie(req, COOKIE);
    // No cookie -> anonymous traffic. That belongs to the GA4 layer, not here.
    if (token) {
      const body = await req.json().catch(() => ({})) as Record<string, unknown>;
      const kind = body.kind === "download" ? "download" : "page";
      await rpc("sales_track_visit", {
        p: {
          token,
          kind,
          path: String(body.path ?? url.pathname).slice(0, 300),
          referrer: String(body.referrer ?? "").slice(0, 300),
          ua,
          country,
        },
      });
    }
    // Always 204, cookie or not: the response must never reveal whether a
    // token is valid or whose it is.
    return new Response(null, { status: 204 });
  }

  // ---- GET /r/<token> : the tracked link itself ----
  const token = tokenFrom(url);
  let dest = "/";
  if (token) {
    const out = await rpc("sales_link_resolve", {
      p: { token, referrer: req.headers.get("referer") ?? "", ua, country },
    });
    if (out?.ok) dest = safePath(out.dest);
  }

  const headers = new Headers({ Location: `${SITE}${dest}` });
  // Set the cookie even on an unknown token, so a probe can't distinguish a
  // valid token from an invalid one by watching for Set-Cookie.
  if (token) {
    headers.append(
      "Set-Cookie",
      `${COOKIE}=${encodeURIComponent(token)}; Domain=.donorsend.app; Path=/; ` +
        `Max-Age=${COOKIE_MAX_AGE}; SameSite=Lax; Secure; HttpOnly`,
    );
  }
  return new Response(null, { status: 302, headers });
});
