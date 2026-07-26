# Per-lead web tracking (HubSpot-style)

Tracks what a **specific person** does after you send them a link: that they
clicked it, when they arrived, which pages they read, and what they
downloaded — surfaced on the lead's timeline in the CRM.

This is the identified layer. Anonymous, aggregate traffic ("how many
visitors, from where") belongs to the GA4 layer described in
`prompts/donorsend-analytics-prompts.md`, and the two are deliberately
separate.

## Status

| Piece | State |
|---|---|
| `sales.links` / `sales.link_hits` schema, contact-scoped | ✅ done |
| `sales_create_link` (accepts `contact_id`) | ✅ done |
| `sales_track_visit` (page / click / download / email_open) | ✅ done |
| `sales_link_resolve` (service_role only) | ✅ done |
| `link-track` edge function (`/r/<token>` + `/track`) | ✅ deployed & verified |
| **Vercel rewrite on donorsend.app** | ⬜ **you need to add this** |
| Marketing-site page-view script | ⬜ needs the app repo |
| CRM "Create tracked link" button + timeline rendering | ⬜ needs the app repo |
| Email open pixel (`/px/<token>.gif`) | ⬜ optional, not built |

The database and endpoint work end-to-end today. What is missing is the
donorsend.app plumbing, which lives in the app repo rather than here.

## 1. Add the rewrite (required)

Tracked links must be served from `donorsend.app`, not from the Supabase
functions domain. This is not cosmetic: the visitor cookie is scoped to
`.donorsend.app`, so a redirect from `*.supabase.co` would record the click
and then lose every page view after it. It is also better for email
deliverability.

In the app repo's `vercel.json`:

```json
{
  "rewrites": [
    {
      "source": "/r/:token",
      "destination": "https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/link-track?t=:token"
    },
    {
      "source": "/track",
      "destination": "https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/link-track"
    }
  ]
}
```

Next.js equivalent, in `next.config.js`, if you prefer:

```js
async rewrites() {
  return [
    { source: '/r/:token',
      destination: 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/link-track?t=:token' },
    { source: '/track',
      destination: 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/link-track' },
  ]
}
```

Verify with `curl -sI https://donorsend.app/r/<token>` — expect a `302` whose
`Location` is the link's destination, plus a `Set-Cookie: ds_visitor=…`.

## 2. Add the page-view script (for post-click tracking)

Without this you still get click tracking. With it you get the full
"read three pages and downloaded the brochure" picture. Drop it on the
marketing site:

```html
<script>
(function () {
  var send = function (kind, path) {
    // Cookie is HttpOnly, so the browser attaches it; this script never
    // reads it. Visitors with no cookie are ignored server-side.
    fetch('/track', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind: kind, path: path, referrer: document.referrer }),
      keepalive: true,
    }).catch(function () {});
  };
  send('page', location.pathname);
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href]');
    if (a && /\.(pdf|docx?|xlsx?|pptx?|zip|csv)(\?|$)/i.test(a.getAttribute('href'))) {
      send('download', a.getAttribute('href'));
    }
  }, true);
})();
</script>
```

## 3. Create links from the CRM

`sales_create_link` already exists and now takes an optional `contact_id`:

```js
const { data } = await supabase.rpc('sales_create_link', {
  p: { lead_id: leadId, contact_id: contactId, label: 'Pricing page', dest: '/pricing' },
})
// tracked URL -> https://donorsend.app/r/${data.token}
```

`dest` is validated to a path on donorsend.app, so it cannot become an open
redirect. `contact_id` is verified to belong to the lead.

## How it behaves

- **Timeline noise control.** One activity row per link per kind per 6 hours,
  so a ten-page browsing session reads as a single "Visited the site" entry
  rather than ten rows. **Downloads always log** — each is a distinct buying
  signal, not session noise.
- **Activity kinds written:** `visit`, `download`, `email_open`. Any CRM UI
  that switches on `kind` needs to render these three, or they will show as
  unknown.
- **Lead scoring** already factors `link_hits` via `sales_recompute_scores`,
  so tracked visits feed the existing score with no extra work.
- **`leads.updated_at` is deliberately not bumped** by a visit: the stale-lead
  list tracks *our* touches, and a hot visitor going stale is exactly the
  nudge you want.

## Privacy and security

- Tokens are ~122 bits (32 hex chars). The old 48-bit default was strengthened
  since a token identifies a person.
- The `ds_visitor` cookie is **HttpOnly** — `/track` reads it server-side, so
  no page script needs it and site XSS cannot exfiltrate whose token it is.
  13-month expiry, `SameSite=Lax`, `Secure`.
- **No raw IP addresses are stored.** Only a coarse country code from the CDN
  header and a user-agent *family* (`Chrome/macOS`), never the full UA string.
- Rate limited to 120 hits/hour per link, inside `sales_track_visit`.
- Unknown tokens and cookie-less posts return exactly the same response as
  valid ones, so the endpoint cannot be used to probe which tokens exist.
- `sales_link_resolve` is `service_role` only; `anon` cannot enumerate tokens.
- All `sales.*` tables remain RLS-on with no policies (deny by default);
  access is via `SECURITY DEFINER` RPCs, matching the rest of the schema.

## Still to do

- **Retention.** No pruning job exists yet. Add a monthly cron deleting
  `sales.link_hits` older than 24 months before this accumulates.
- **Email open pixel.** Not built. Note that Apple Mail Privacy Protection
  pre-fetches images, so opens are unreliable — clicks are the real signal.
- **Notification on visit.** The prompt called for alerting sales when an
  active lead visits; the timeline entry exists, but nothing pushes yet.
