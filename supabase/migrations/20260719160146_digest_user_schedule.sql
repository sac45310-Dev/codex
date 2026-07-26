-- Per-user digest scheduling (Scott's request): each user picks the day
-- and hour in THEIR timezone. The cron now fires hourly and the function
-- matches each user's local (day, hour); last_digest_at guards double-sends.
alter table public.users
  add column digest_day smallint not null default 1 check (digest_day between 0 and 6),
  add column digest_hour smallint not null default 7 check (digest_hour between 0 and 23),
  add column digest_tz text not null default 'America/Los_Angeles',
  add column last_digest_at timestamptz;

select cron.unschedule('weekly-digest-email');
select cron.schedule(
  'weekly-digest-email',
  '5 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/email-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')
    ),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
