# Prospect Pipeline — Auto-Load Scouts & Decision-Makers

Turns the discovered **scouts** (`sales.scout_candidates`) and **decision-makers**
(`sales.contacts`) into a first-class **Prospects** surface in the staff CRM
console: a filterable prospect list, a detail view with nested contacts, and an
auto-load "N new prospects" badge.

This document is the contract between the database API (shipped in this repo)
and the console frontend (lives in the admin app).

---

## What shipped in this repo

| Layer | Object | Purpose |
|-------|--------|---------|
| Migration | `supabase/migrations/20260723000000_prospects_pipeline.sql` | All DB objects below (additive, read-only over existing data) |
| View | `sales.v_prospect_contact_map` | Unifies the singular FK + the `uuid[]` many-to-many so no contact is orphaned |
| View | `sales.v_prospect_contacts` | Contacts per prospect, each tagged with a `confidence_tier` |
| View | `sales.v_prospects` | One row per scout with rolled-up contact stats (counts by tier, best confidence, has-email/phone) |
| Function | `sales.confidence_tier(smallint)` | Single source of truth for the badge tier |
| Table | `sales.prospect_sync_state` | Per-staff "last synced" bookmark for the badge |
| RPC | `public.sales_prospects_list(...)` | `GET /prospects` — filter/sort/paginate + total |
| RPC | `public.sales_prospect_detail(uuid)` | `GET /prospects/:id` — prospect + contacts |
| RPC | `public.sales_prospects_summary()` | Badge data: totals, tier breakdown, `new_since_sync` |
| RPC | `public.sales_prospects_mark_synced()` | Clears the caller's "new" badge |
| Client | `web/src/lib/prospects.ts` | Typed supabase-js wrappers + `tierMeta()` / `bestEmail()` helpers |

**Access model.** The `sales` schema is not exposed to PostgREST and its tables
run RLS with no policies, so — exactly like the existing `sales_get_lead` /
`sales_cron_queue` RPCs — access is via `public.sales_*` `SECURITY DEFINER`
functions guarded by `platform_role()`. The console calls them with the staff
member's JWT; the service/cron lane (edge functions, scheduled sync) is allowed
via the `auth.role() = 'service_role'` bypass. No new PostgREST exposure, no new
RLS surface.

**Nothing destructive.** Every object is `CREATE OR REPLACE` / `CREATE IF NOT
EXISTS`. No existing table, column, or row is modified. The only writable object
is `sales.prospect_sync_state`, which stores one timestamp per staff user.

---

## Spec reconciliation (what the original UI spec assumed vs. reality)

The API keeps the spec's intent and field *names on the wire* where sensible,
but the underlying schema differs from the spec in several ways. These were
verified against the live database before building:

| Spec assumption | Reality | How it's handled |
|-----------------|---------|------------------|
| `scout_candidates.organization_name`, `website_url` | Columns are `org_name`, `website` | Views alias to `org_name` / `website` (+ derived `domain`) |
| `status IN ('pending','new','approved','enriched')` | Real values: `pending`, `approved`, `rejected`, `skipped` | List defaults to the active set `{pending, approved}`; caller may override |
| `contacts.scout_candidate_ids @> ARRAY[?]` is the mapping | Real link is the **singular** `scout_candidate_id` (1,825 rows); the `uuid[]` array covers only 43 | `v_prospect_contact_map` UNIONs both, so all mappings are honored |
| "Add `prospect_id` field", "add `contact_prospect_mapping`" | `scout_candidates.id` *is* the prospect id; `contacts.scout_candidate_id` *is* the mapping | No redundant columns added |
| `org_type = 'individual'` exact match | Mixed casing (`individual` + `Individual`, `organization` + `Organization`) | Normalized through the existing `sales.norm_org_type()`; filter on the normalized value |
| Counts: 1,016 scouts / 1,871 contacts | 1,863 scouts (1,086 individuals; 1,228 active) / 1,871 contacts (1,828 mapped, 43 orphaned) | Real counts surfaced by `sales_prospects_summary()` |

---

## Confidence → badge legend

`sales.confidence_tier()` maps the 1–10 contact confidence to a tier. `tierMeta()`
in the client turns that into label + stars + hint.

| Confidence | Tier | Badge | Meaning |
|-----------|------|-------|---------|
| 9–10 | `primary` | ⭐⭐⭐⭐⭐ Primary Contact | Direct email/phone found — ready for outreach |
| 7–8 | `secondary` | ⭐⭐⭐⭐ Secondary Contact | Inferred — likely valid, verify before send |
| 5–6 | `role` | ⭐⭐⭐ Role | Role-based — use org email if no direct |
| 3–4 | `org` | ⭐⭐ Org | Org email only — fallback, lower conversion |
| 1–2 | `low` | ⭐ Low | Low confidence |
| null | `unknown` | — | No score |

---

## Frontend wiring

Everything below uses `web/src/lib/prospects.ts`.

### Prospect list view

```ts
import { listProspects } from '@/lib/prospects'

const { total, rows } = await listProspects(supabase, {
  orgType: 'individual',
  onlyWithContacts: true,
  sort: 'contacts',       // newest | contacts | confidence | name | fit
  limit: 50,
  offset: page * 50,
})
```

Card fields map straight from `ProspectRow`: `org_name`, `city`/`state`,
`domain` (link to `website`), `contact_count` ("43 contacts"), `best_confidence`,
`status` badge, `created_at` ("Added 7/23/26"). The tier counts
(`primary_count`, `secondary_count`, …) drive the mini badge row on each card.

Filters from the spec map to params: high-confidence-only → `minConfidence: 9`;
has-direct-email → `hasEmail: true`; has-phone → `hasPhone: true`; by state →
`state`; by discovery date → `since`; by type → `orgType`.

### Prospect detail view

```ts
import { getProspect, tierMeta, bestEmail } from '@/lib/prospects'

const detail = await getProspect(supabase, prospectId)
// detail.contacts is already sorted primary-first, then confidence desc.
for (const c of detail!.contacts) {
  const meta = tierMeta(c.confidence_tier)   // label + stars + hint
  const send = bestEmail(c)                  // direct email, else org fallback
}
```

### Auto-load badge (spec Part 4)

```ts
import { getProspectSummary, markProspectsSynced } from '@/lib/prospects'

const s = await getProspectSummary(supabase)
// Badge: `${s.new_since_sync} New Prospects` when > 0.
// On the user opening the Prospects view:
await markProspectsSynced(supabase)          // clears their badge
```

`new_since_sync` is **per staff user** (each person has their own bookmark), so
one teammate clearing the badge doesn't hide new prospects from another. The
scouts already live in the database — "auto-load" here means *surfacing* them,
so there is no bulk copy/ETL step and no risk of duplication.

- **Option A (startup):** call `getProspectSummary` on console load; show the badge.
- **Option B (admin trigger):** a "Sync Scout Database" button that re-fetches
  the list and calls `markProspectsSynced`.
- **Option C (scheduled):** a cron edge function can call the RPCs with the
  service role (the guard allows `service_role`) to compute deltas for a digest.

### Promoting a prospect into the pipeline (spec Part 5, Step 3)

A prospect is a scout candidate. Converting it to a working **lead** already has
a home in the CRM (`sales_upsert_lead` + the existing scout-approve flow, which
sets `scout_candidates.lead_id`). The prospect row exposes `lead_id` so the UI
can show "already in pipeline" vs. "convert". Outreach itself continues to run
through the existing `lead-assist` (draft) and `sales-outreach-send` (human
send) functions — this feature deliberately does **not** send anything; it feeds
the existing outreach workflow, honoring the no-autonomous-outreach rule.

---

## Validated against live data (2026-07-23)

- `sales_prospects_summary` → 1,228 active prospects, 1,828 mapped contacts,
  tiers {primary 257, secondary 328, role 315, org 963}.
- `sales_prospects_list(org_type=individual, only_with_contacts, sort=contacts)`
  → 893 rows; top = *Converge Minnesota Twin Cities*, 44 contacts (41 primary),
  `has_direct_email: true`.
- `sales_prospect_detail(<Converge>)` → 44 contacts, primary-first; top contact
  tier `primary` with a direct email.

---

## Follow-ups (not in this cut)

- Console UI components (list/detail/badge) — build against `prospects.ts`.
- A `sales_prospect_convert(p_id)` convenience RPC if the console wants
  one-click scout→lead promotion from the prospect view.
- Optional scheduled digest edge function for Option C.
