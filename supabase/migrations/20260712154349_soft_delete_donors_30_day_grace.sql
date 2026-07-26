-- Soft delete: "Delete donor" now parks the record in status 'deleted'
-- (shown under Archived) for 30 days before a cron purge removes it for
-- real — an accidental delete can be restored during the grace window.
alter table donors drop constraint donors_status_check;
alter table donors add constraint donors_status_check
  check (status = any (array['active'::text, 'archived'::text, 'deceased'::text, 'deleted'::text]));
alter table donors add column if not exists deleted_at timestamptz;

-- Daily purge; donor FK cascades clean up all child rows.
select cron.schedule(
  'donor-purge-daily',
  '15 11 * * *',
  $$delete from public.donors where status = 'deleted' and deleted_at < now() - interval '30 days'$$
);
