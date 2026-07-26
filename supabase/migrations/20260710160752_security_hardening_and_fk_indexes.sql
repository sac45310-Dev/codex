-- Pin search_path on the one function missing it.
alter function public.set_updated_at() set search_path = public;

-- Internal trigger functions should not be callable through the REST API.
-- (Postgres checks trigger EXECUTE at creation time, so triggers keep firing.)
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.set_tenant_id() from anon, authenticated, public;

-- RLS helper: authenticated must keep EXECUTE (policies call it at query
-- time), but anon has no business calling it.
revoke execute on function public.auth_tenant_id() from anon, public;

-- Covering indexes for foreign keys. The tenant_id ones back every RLS check.
create index if not exists consent_events_tenant_idx on public.consent_events (tenant_id);
create index if not exists consent_events_recorded_by_idx on public.consent_events (recorded_by);
create index if not exists custom_field_defs_tenant_idx on public.custom_field_defs (tenant_id);
create index if not exists custom_field_values_tenant_idx on public.custom_field_values (tenant_id);
create index if not exists custom_field_values_field_def_idx on public.custom_field_values (field_def_id);
create index if not exists donor_families_tenant_idx on public.donor_families (tenant_id);
create index if not exists donor_family_members_tenant_idx on public.donor_family_members (tenant_id);
create index if not exists donor_family_members_donor_idx on public.donor_family_members (donor_id);
create index if not exists donor_notes_tenant_idx on public.donor_notes (tenant_id);
create index if not exists donor_notes_author_idx on public.donor_notes (author_user_id);
create index if not exists donors_created_by_idx on public.donors (created_by);
create index if not exists key_dates_tenant_idx on public.key_dates (tenant_id);
create index if not exists segment_members_tenant_idx on public.segment_members (tenant_id);
create index if not exists segments_tenant_idx on public.segments (tenant_id);
create index if not exists users_tenant_idx on public.users (tenant_id);
