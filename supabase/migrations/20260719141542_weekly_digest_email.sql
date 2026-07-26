-- Weekly digest email (EMAILS.md): opt-out flag + a per-user unsubscribe
-- token (one-click unsubscribe from the email itself, no login needed).
alter table public.users
  add column digest_opt_out boolean not null default false,
  add column digest_token uuid not null default gen_random_uuid();

-- Monday 14:00 UTC ≈ 7am Pacific — the "plan your week" moment.
select cron.schedule(
  'weekly-digest-email',
  '0 14 * * 1',
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
