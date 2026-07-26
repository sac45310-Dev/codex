# DonorSend Website Analytics — Implementation Prompts

Two ready-to-paste prompts for a Claude Code session working on the DonorSend
app (Supabase project `leuhdxomjpoaiacxrwbz`). They are independent — run
Prompt 1 for standard site analytics, Prompt 2 for HubSpot-style per-lead
tracking — but they share event-naming and UTM conventions, so if you run
both, run Prompt 1 first.

Both prompts assume the session has access to the DonorSend app codebase and
the Supabase MCP tools. Fill in anything marked `<LIKE THIS>` before pasting.

---

## Prompt 1 — Standard website traffic & usage analytics (industry standard)

```
You are working on DonorSend, a donor-relationship/CRM SaaS app backed by the
Supabase project `leuhdxomjpoaiacxrwbz`. I want industry-standard website
analytics on the public marketing site and the app, so I can answer: how much
traffic do we get, where does it come from, when does it arrive, what do
visitors do, and which pages/campaigns convert into signups.

Implement the following:

1. **Google Analytics 4 as the primary tool.**
   - Add the GA4 tag (gtag.js or Google Tag Manager if you think a tag
     manager is more maintainable — recommend one and explain why) to the
     marketing site and the app shell. Measurement ID will be provided as an
     environment variable (`NEXT_PUBLIC_GA_MEASUREMENT_ID` or the equivalent
     for this codebase's framework — inspect the repo and follow its
     conventions).
   - Enable GA4 enhanced measurement: page views, scrolls, outbound clicks,
     site search, file downloads.
   - Configure IP anonymization and disable Google Signals ad
     personalization by default.

2. **A standard event taxonomy** (GA4 recommended-event names where one
   exists, snake_case custom events otherwise):
   - `page_view` (automatic), `sign_up`, `login`, `generate_lead` (any
     contact/demo form submit), `file_download` (automatic, but verify it
     fires on our PDF/resource links), `video_start`/`video_complete` for
     embedded videos, and `begin_checkout`/`purchase` if the plan-upgrade
     flow is reachable from the web.
   - Mark `sign_up` and `generate_lead` as conversions.

3. **UTM discipline.** Document (in a short `docs/analytics.md`) the UTM
   convention every outbound campaign must use:
   `utm_source` (google, facebook, newsletter, partner name),
   `utm_medium` (cpc, email, social, referral),
   `utm_campaign` (kebab-case campaign name), optional `utm_content` for A/B
   variants. Add a small helper that builds campaign URLs with these params.

4. **First-party mirror of key events.** The app already has a
   `public.analytics_events` table (columns: id, tenant_id, user_id, event,
   props jsonb, created_at). Send the same conversion events (sign_up,
   generate_lead, file_download) there too via our existing insert path, so
   we own a copy of the data and can join it to tenants/users later. Do NOT
   create a parallel table; reuse this one and follow its existing event
   naming if any code already writes to it.

5. **Consent & privacy.**
   - Add a lightweight cookie-consent banner on the marketing site (EU-style
     opt-in for analytics cookies; use GA Consent Mode v2 so GA still gets
     cookieless pings when consent is denied).
   - Do not send email addresses or names to GA. User IDs may be sent only
     as opaque UUIDs.
   - Note in docs/analytics.md what we collect and why, for the privacy
     policy.

6. **Reporting.** In docs/analytics.md, list the 5 GA4 reports/explorations
   to check weekly: traffic acquisition by source/medium, landing pages,
   conversions by campaign, day-of-week/hour-of-day traffic pattern, and
   tech/device breakdown. Include click-path instructions for someone who
   has never opened GA4.

Also give me your opinion at the end: if you think a privacy-first tool
(e.g. Plausible or Umami self-hosted next to Supabase) is a better fit than
GA4 for a donor-facing product, say so and estimate the effort to run both
in parallel for a quarter.

Constraints: follow the existing code style and framework conventions in the
repo; every new table/column needs RLS consistent with the app's tenant
model; nothing may break if the GA measurement ID env var is unset (analytics
must fail silent, never block rendering). Test the tag fires with GA4
DebugView instructions written into docs/analytics.md.
```

---

## Prompt 2 — HubSpot-style per-lead tracking (tracked links, visits, downloads)

```
You are working on DonorSend, a donor-relationship/CRM SaaS app backed by the
Supabase project `leuhdxomjpoaiacxrwbz`. I want HubSpot-style contact-level
tracking for OUR OWN sales pipeline: when we email a prospect a link, I want
to know that THAT person clicked it, when they arrived, which pages they
read, and what they downloaded — visible as a timeline on the lead's record
in the CRM.

Important: the schema is already half-built. `sales.links` (id, lead_id,
token, label, dest, created_by, hit_count, last_hit_at, created_at) and
`sales.link_hits` (id, link_id, lead_id, path, referrer, created_at) exist
but are empty and nothing writes to them. `sales.leads`, `sales.contacts`
(~2,900 rows), and `sales.activities` (kind, subject, body, meta jsonb,
lead_id, contact_id) are live. Build on these tables — extend them with
migrations if needed rather than replacing them.

Implement:

1. **Tracked short links.**
   - An edge function (or API route, whichever fits the codebase) at
     `/r/<token>`: looks up `sales.links` by token, records a row in
     `sales.link_hits` (capture referrer, user-agent, and coarse metadata in
     a meta jsonb column — add one via migration), increments
     hit_count/last_hit_at, sets a first-party cookie `ds_visitor=<token>`
     (13-month expiry, SameSite=Lax), then 302-redirects to `dest`.
   - Tokens must be unguessable (>= 12 chars, crypto-random) since a token
     identifies a person.
   - A "Create tracked link" action in the CRM lead view: pick a
     destination URL (default our site), auto-generate the token, copy
     button for the short URL. Add `contact_id` to `sales.links` via
     migration so a link can target a specific contact, not just a lead.

2. **Continued on-site tracking after the click.**
   - A tiny first-party script on the marketing site: if the `ds_visitor`
     cookie is present, POST page views and file-download clicks to a
     `/track` endpoint, which resolves the token back to the link/lead/
     contact and appends rows to `sales.link_hits` (path = the page viewed,
     or the file URL with a `kind: 'download'` marker in meta).
   - The endpoint must validate the token exists and rate-limit per token;
     it will be hit from the public internet.
   - Visitors without the cookie are ignored by this system entirely
     (anonymous traffic belongs to the GA4 layer, not this one).

3. **Email integration.**
   - When composing outreach email to a prospect from the CRM (or when I
     paste links into an external email tool), every link to our site should
     be replaceable with a tracked link: add a "tracked links" helper in the
     compose flow that swaps URLs for `/r/<token>` links bound to that
     contact.
   - Optional, behind a flag: a 1x1 open-tracking pixel endpoint
     `/px/<token>.gif` logging an `email_open` hit. Note in the docs that
     Apple Mail privacy proxying makes opens unreliable; clicks are the real
     signal.

4. **Timeline & surfacing.**
   - On each qualifying hit (first click of a link, first visit to a page,
     any download), insert a `sales.activities` row (kind: 'web_visit' /
     'link_click' / 'download', subject like "Clicked: <label>", meta with
     the raw hit reference) so the existing lead timeline shows it
     chronologically with calls and emails. Dedupe so a 10-page browsing
     session becomes one 'web_visit' activity with pages listed in meta,
     not 10 rows.
   - Lead list: add "last seen" and "total visits" (derivable from
     links.last_hit_at / hit_count aggregates — a view is fine).
   - Notification hook: when a lead whose deal stage is past 'new' visits
     the site, fire the app's existing notification path (push_tokens /
     scheduled messages — inspect what exists) or at minimum write a
     platform event, so sales can strike while the iron is hot.

5. **Privacy & hygiene.**
   - RLS on all new/changed sales.* objects consistent with the existing
     sales schema policies; the /r and /track endpoints run with service
     role but must never expose data in responses.
   - Store only coarse geo (country/region from CDN headers if available),
     never raw IP addresses at rest. Truncate user-agent to family/OS.
   - A note in docs/lead-tracking.md covering: what this tracks, that it is
     first-party and per-recipient, CAN-SPAM/GDPR posture (tracked links in
     b2b outreach + unsubscribe handling via the existing
     sales.email_blocklist), and a 24-month retention/pruning job for
     link_hits.

Acceptance test to run before you finish: create a link for a test lead,
curl the /r/ URL, confirm the redirect + link_hits row + activities row +
hit_count increment; then simulate a /track page view with the cookie token
and confirm it lands on the same lead's timeline.

Constraints: follow existing code conventions; migrations via the app's
normal migration path; everything fails safe (a broken tracker must never
break the site or leak whose token is whose).
```

---

## How the two layers relate

| | Layer 1 (GA4) | Layer 2 (tracked links) |
|---|---|---|
| Answers | How many people, from where, when | Which specific person did what |
| Identity | Anonymous/aggregate | Known contact in `sales.contacts` |
| Powered by | GA4 + `public.analytics_events` | `sales.links` + `sales.link_hits` + `sales.activities` |
| Consent model | Cookie-consent banner, Consent Mode | First-party, tied to our outreach to that person |

A visit can appear in both: GA4 counts it in campaign traffic (via UTMs on
the destination URL), while the tracked-link layer pins it to the individual.
