# supabase/migrations

Complete migration history for the DonorSend Supabase project
(`leuhdxomjpoaiacxrwbz`) — all 126 migrations, from `20260710160457` through
`20260726201206`.

Filenames follow the Supabase CLI convention `<version>_<name>.sql`, where
`<version>` is the timestamp recorded in the project's migration table, so
these files line up 1:1 with `supabase migration list`.

## Provenance

These files were extracted verbatim from
`supabase_migrations.schema_migrations` on the remote project (the CLI was not
available in the environment where they were captured). Each file is the exact
SQL that was applied — comments and formatting preserved, nothing reformatted
or hand-edited.

Fidelity was verified by comparing a per-migration MD5 of every file against
the same hash computed server-side: **126/126 matched, zero mismatches.**

### One deliberate exception: redacted credentials

`20260710234930_app_config_table.sql` is the **only** file that differs from
what was applied. It seeded `public.app_config` with a live Twilio Account SID
and auth token as SQL literals; those two values are replaced with
`REDACTED_SEE_NOTE` here, and the file carries a header comment saying so.
GitHub push protection blocks the real values, and committing them would leak
working credentials.

The real values are still in `public.app_config` in the database — this changes
nothing at runtime. Anyone rebuilding a local stack from these migrations must
supply their own Twilio credentials.

Because those credentials existed in plaintext in the migration record, treat
them as exposed to anyone who has had database access and **rotate them in the
Twilio console**, updating `public.app_config` with the new values.

## Working with these

Because the migrations are already applied remotely, `supabase db push` will
skip them by version. A fresh environment can be built from them with:

```bash
supabase db reset          # local stack, replays every migration in order
```

New migrations should be added here with a later timestamp — use
`supabase migration new <name>` so the version format stays consistent.

## Notable security migrations

The two most recent entries came out of a security review of the project's
RLS and grant posture:

| Version | Name | What it does |
|---|---|---|
| 20260726194553 | harden_scout_queue_sync_state_and_cron_ticks | Enables RLS on `sales.scout_hunt_queue` and `sales.prospect_sync_state`, revokes client-role table privileges, and restricts the `scout_hunt_tick` / `lead_research_tick` cron functions to `service_role` (they were anon-executable with no authorization check). |
| 20260726201206 | tighten_telemetry_insert_policies_tenant_scope | Replaces `WITH CHECK (true)` on the `insert_own` policies for `public.analytics_events` and `public.client_errors` with a tenant-scoped check, closing a cross-tenant write-forgery hole. |
