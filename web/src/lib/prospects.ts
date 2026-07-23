// Prospect Pipeline client — typed wrappers over the sales_prospects_* RPCs.
//
// These call public.sales_* SECURITY DEFINER functions with the signed-in
// staff member's JWT (same pattern the console already uses for sales_get_lead
// etc.). The platform_role() guard inside each function enforces staff-only
// access, so there is nothing security-sensitive to gate on the client.
//
// Drop this into the admin console and import from your feature components.
// It depends only on an initialized supabase-js client.

import type { SupabaseClient } from '@supabase/supabase-js'

// ---------------------------------------------------------------------------
// Types (mirror the RPC JSON payloads)
// ---------------------------------------------------------------------------

/** Badge tier derived from a contact's 1–10 confidence score. */
export type ConfidenceTier = 'primary' | 'secondary' | 'role' | 'org' | 'low' | 'unknown'

export interface ProspectRow {
  prospect_id: string
  org_name: string
  org_type: string | null      // normalized, e.g. "individual"
  org_type_raw: string | null
  website: string | null
  domain: string | null
  city: string | null
  state: string | null
  status: string               // pending | approved | rejected | skipped
  summary: string | null
  fit_score: number | null
  fit_reason: string | null
  source_query: string | null
  lead_id: string | null       // set once promoted into the leads pipeline
  created_at: string
  contact_count: number
  primary_count: number
  secondary_count: number
  role_count: number
  org_count: number
  best_confidence: number | null
  has_direct_email: boolean
  has_phone: boolean
}

export interface ProspectContact {
  prospect_id: string
  contact_id: string
  name: string
  title: string | null
  email: string | null
  email_kind: string | null
  org_email: string | null
  phone: string | null
  phone_kind: string | null
  org_phone: string | null
  linkedin_url: string | null
  city: string | null
  state: string | null
  confidence: number | null
  confidence_tier: ConfidenceTier
  is_primary: boolean
  verified: boolean
  source_url: string | null
  enriched_at: string | null
  created_at: string
}

export interface ProspectListResult {
  total: number
  limit: number
  offset: number
  rows: ProspectRow[]
}

export interface ProspectDetail {
  prospect: ProspectRow
  contacts: ProspectContact[]
}

export interface ProspectSummary {
  total_prospects: number
  total_contacts: number
  by_status: Record<string, number>
  by_tier: { primary: number; secondary: number; role: number; org: number }
  last_synced_at: string | null
  new_since_sync: number
}

export type ProspectSort = 'newest' | 'contacts' | 'confidence' | 'name' | 'fit'

export interface ProspectListParams {
  search?: string
  orgType?: string            // normalized value, e.g. "individual"
  status?: string[]           // defaults server-side to ['pending','approved']
  state?: string
  minConfidence?: number      // best_confidence >= this
  hasEmail?: boolean
  hasPhone?: boolean
  onlyWithContacts?: boolean
  since?: string              // ISO timestamp; created_at >= this
  sort?: ProspectSort
  limit?: number
  offset?: number
}

// ---------------------------------------------------------------------------
// RPC wrappers
// ---------------------------------------------------------------------------

/** GET /prospects — filterable, sortable, paginated. */
export async function listProspects(
  supabase: SupabaseClient,
  params: ProspectListParams = {},
): Promise<ProspectListResult> {
  const { data, error } = await supabase.rpc('sales_prospects_list', {
    p_search: params.search ?? null,
    p_org_type: params.orgType ?? null,
    p_status: params.status ?? null,
    p_state: params.state ?? null,
    p_min_confidence: params.minConfidence ?? null,
    p_has_email: params.hasEmail ?? null,
    p_has_phone: params.hasPhone ?? null,
    p_only_with_contacts: params.onlyWithContacts ?? false,
    p_since: params.since ?? null,
    p_sort: params.sort ?? 'newest',
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  })
  if (error) throw error
  return data as ProspectListResult
}

/** GET /prospects/:id — prospect plus its decision-makers (best first). */
export async function getProspect(
  supabase: SupabaseClient,
  prospectId: string,
): Promise<ProspectDetail | null> {
  const { data, error } = await supabase.rpc('sales_prospect_detail', { p_id: prospectId })
  if (error) throw error
  return (data as ProspectDetail | null) ?? null
}

/** Auto-load badge data: totals, tier breakdown, and "new since I last synced". */
export async function getProspectSummary(supabase: SupabaseClient): Promise<ProspectSummary> {
  const { data, error } = await supabase.rpc('sales_prospects_summary')
  if (error) throw error
  return data as ProspectSummary
}

/** Clear the caller's "new prospects" badge (marks now as their sync point). */
export async function markProspectsSynced(
  supabase: SupabaseClient,
): Promise<{ ok: boolean; last_synced_at: string }> {
  const { data, error } = await supabase.rpc('sales_prospects_mark_synced')
  if (error) throw error
  return data as { ok: boolean; last_synced_at: string }
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

export interface TierMeta {
  label: string
  stars: number       // filled stars, 1–5
  hint: string
}

/** Badge presentation for a confidence tier (matches the spec's legend). */
export function tierMeta(tier: ConfidenceTier): TierMeta {
  switch (tier) {
    case 'primary':
      return { label: 'Primary Contact', stars: 5, hint: 'Direct email/phone found — ready for outreach' }
    case 'secondary':
      return { label: 'Secondary Contact', stars: 4, hint: 'Inferred contact — likely valid, verify before send' }
    case 'role':
      return { label: 'Role', stars: 3, hint: 'Role-based — use org email if no direct address' }
    case 'org':
      return { label: 'Org', stars: 2, hint: 'Org email only — fallback contact, lower conversion' }
    case 'low':
      return { label: 'Low', stars: 1, hint: 'Low-confidence contact' }
    default:
      return { label: 'Unknown', stars: 0, hint: 'No confidence score' }
  }
}

/** The address you'd actually send to: direct email first, org email fallback. */
export function bestEmail(c: ProspectContact): { email: string; kind: 'direct' | 'org' } | null {
  if (c.email) return { email: c.email, kind: 'direct' }
  if (c.org_email) return { email: c.org_email, kind: 'org' }
  return null
}
