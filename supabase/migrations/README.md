# supabase/migrations

Migration history for the DonorSend Supabase project (`leuhdxomjpoaiacxrwbz`).

Filenames follow the Supabase CLI convention `<version>_<name>.sql`, where
`<version>` is the timestamp recorded in the project's migration table — so
these files line up 1:1 with `supabase migration list` / the `list_migrations`
MCP tool.

**Note on completeness:** the project has ~127 applied migrations, but this
directory was created after the fact and currently holds only the two security
migrations below. The earlier history lives in the remote project, not here.
Pull it down with `supabase db pull` if you want the full set tracked in git.

## Contents

| Version | Name | What it does |
|---|---|---|
| 20260726194553 | harden_scout_queue_sync_state_and_cron_ticks | Enables RLS on `sales.scout_hunt_queue` and `sales.prospect_sync_state`, revokes client-role table privileges, and restricts the `scout_hunt_tick` / `lead_research_tick` cron functions to `service_role` (they were anon-executable with no authorization check). |
| 20260726201206 | tighten_telemetry_insert_policies_tenant_scope | Replaces `WITH CHECK (true)` on the `insert_own` policies for `public.analytics_events` and `public.client_errors` with a tenant-scoped check, closing a cross-tenant write-forgery hole. |

Both are already applied to the remote project. They are idempotent enough to
re-run, but re-applying via the CLI against a project that already has them
will be skipped by version.
