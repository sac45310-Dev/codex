-- Error tracking v2, phase 1 (ERRORS.md): grouping + multi-source capture.
-- client_errors keeps its historical name but is now the event stream for
-- ALL sources (client JS, edge functions, db sweeps). error_groups rolls
-- occurrences into one row per distinct bug with a triage status and
-- release-aware regression detection.

alter table public.client_errors
  add column if not exists fingerprint text,
  add column if not exists source text not null default 'client',
  add column if not exists severity text not null default 'error',
  add column if not exists release text,
  add column if not exists user_id uuid default auth.uid(),
  add column if not exists context jsonb;
alter table public.client_errors
  add constraint client_errors_source_chk check (source in ('client','edge','db')),
  add constraint client_errors_severity_chk check (severity in ('warning','error','fatal'));
create index if not exists client_errors_fp_idx
  on public.client_errors (fingerprint, created_at desc);
create index if not exists client_errors_created_idx
  on public.client_errors (created_at desc);

-- Fingerprint: normalized message + normalized url path. Ids, numbers, and
-- quoted strings are stripped so "donor 123 not found" and "donor 456 not
-- found" are the same bug. Stack frames are deliberately NOT hashed: the
-- bundle is minified and frame names/offsets change every release, which
-- would split one bug into a group per deploy.
create or replace function public.error_fingerprint(p_message text, p_url text)
returns text language sql immutable as $$
  select md5(
    regexp_replace(
      regexp_replace(
        regexp_replace(lower(left(coalesce(p_message, 'unknown'), 300)),
          '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<id>', 'g'),
        '''[^'']*''|"[^"]*"', '<str>', 'g'),
      '\d+', '<n>', 'g')
    || '|' ||
    regexp_replace(
      regexp_replace(coalesce(split_part(p_url, '?', 1), ''), '^https?://[^/]+', ''),
      '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+', '<id>', 'g')
  );
$$;

create table public.error_groups (
  fingerprint text primary key,
  message_sample text not null,
  source text not null default 'client',
  severity text not null default 'error',
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  event_count bigint not null default 0,
  status text not null default 'open' check (status in ('open','resolved','ignored')),
  status_changed_by uuid,
  resolved_at timestamptz,
  resolved_release text,
  regressed_at timestamptz,
  last_alerted_at timestamptz
);
-- RLS on, zero policies: reachable only through service role and the
-- security-definer admin_* RPCs (same posture as app_config).
alter table public.error_groups enable row level security;

-- One BEFORE INSERT trigger does both jobs: fill the fingerprint and roll
-- the event into its group. A resolved group that sees a new event from a
-- DIFFERENT release than it was resolved in reopens as a regression;
-- 'ignored' stays ignored forever (that's what ignoring means).
create or replace function public.error_event_ingest()
returns trigger language plpgsql security definer set search_path to public as $$
begin
  if new.fingerprint is null then
    new.fingerprint := error_fingerprint(new.message, new.url);
  end if;
  insert into error_groups as g
    (fingerprint, message_sample, source, severity, event_count, first_seen, last_seen)
  values
    (new.fingerprint, left(new.message, 300), new.source, new.severity, 1,
     new.created_at, new.created_at)
  on conflict (fingerprint) do update set
    event_count = g.event_count + 1,
    last_seen   = greatest(g.last_seen, excluded.last_seen),
    severity    = case when excluded.severity = 'fatal' then 'fatal' else g.severity end,
    regressed_at = case
      when g.status = 'resolved' and new.release is distinct from g.resolved_release
      then now() else g.regressed_at end,
    status = case
      when g.status = 'resolved' and new.release is distinct from g.resolved_release
      then 'open' else g.status end;
  return new;
end $$;

create trigger trg_error_event_ingest
  before insert on public.client_errors
  for each row execute function error_event_ingest();

-- Backfill: fingerprint + group the rows that already exist.
update public.client_errors
  set fingerprint = error_fingerprint(message, url)
  where fingerprint is null;
insert into public.error_groups
  (fingerprint, message_sample, source, severity, event_count, first_seen, last_seen)
select fingerprint, left(max(message), 300), 'client', 'error',
       count(*), min(created_at), max(created_at)
from public.client_errors
where fingerprint is not null
group by fingerprint
on conflict (fingerprint) do nothing;

-- ============ Integrity sweep (hourly) =====================================
-- Exceptions never fire for silent data drift; this watches invariants and
-- background machinery and logs violations as db-source events. Each check
-- dedupes on its own fingerprint so a persistent condition logs once a day,
-- not once an hour.
create or replace function public.run_integrity_sweep()
returns void language plpgsql security definer set search_path to public as $$
begin
  -- 1. pg_cron jobs that failed (the machinery itself breaking).
  insert into client_errors (message, url, source, severity, fingerprint, context)
  select 'Cron job failed: ' || j.jobname, null, 'db', 'error',
         md5('cron-failed|' || j.jobname),
         jsonb_build_object('job', j.jobname,
                            'return_message', left(d.return_message, 500),
                            'start_time', d.start_time)
  from cron.job_run_details d
  join cron.job j on j.jobid = d.jobid
  where d.status = 'failed'
    and d.start_time > now() - interval '65 minutes'
    and not exists (
      select 1 from client_errors ce
      where ce.fingerprint = md5('cron-failed|' || j.jobname)
        and ce.context->>'start_time' = d.start_time::text);

  -- 2. Soft-delete invariant (CLAUDE.md): deleted donors must carry
  --    deleted_at, and only deleted donors may carry it.
  insert into client_errors (message, source, severity, tenant_id, fingerprint, context)
  select 'Soft-delete invariant violated: donor status/deleted_at mismatch',
         'db', 'warning', d.tenant_id, md5('integrity|soft-delete'),
         jsonb_build_object('donor_id', d.id, 'status', d.status,
                            'deleted_at', d.deleted_at)
  from donors d
  where ((d.status = 'deleted') <> (d.deleted_at is not null))
    and not exists (
      select 1 from client_errors ce
      where ce.fingerprint = md5('integrity|soft-delete')
        and ce.created_at > now() - interval '1 day');

  -- 3. Consent audit invariant (CLAUDE.md hard rule 1): any donor with a
  --    consent status must have at least one consent_events audit row —
  --    a violation means something wrote consent without record_consent.
  insert into client_errors (message, source, severity, tenant_id, fingerprint, context)
  select 'Consent set without audit trail: donor has consent_status but no consent_events',
         'db', 'error', d.tenant_id, md5('integrity|consent-audit'),
         jsonb_build_object('donor_id', d.id, 'consent_status', d.consent_status)
  from donors d
  where d.consent_status is not null and d.consent_status <> 'none'
    and not exists (select 1 from consent_events e where e.donor_id = d.id)
    and not exists (
      select 1 from client_errors ce
      where ce.fingerprint = md5('integrity|consent-audit')
        and ce.created_at > now() - interval '1 day');
end $$;

select cron.schedule(
  'error-integrity-sweep',
  '20 * * * *',
  $$select public.run_integrity_sweep()$$
);

-- ============ Retention ====================================================
-- Events: 90 days. Groups: resolved/ignored ones quiet for 30+ days go too
-- (an open group is a live bug and stays regardless of age).
select cron.schedule(
  'error-purge-daily',
  '40 8 * * *',
  $$
  delete from public.client_errors where created_at < now() - interval '90 days';
  delete from public.error_groups
    where status in ('resolved','ignored')
      and last_seen < now() - interval '30 days';
  $$
);
