-- Daily referral qualification + reward run (13:00 UTC), REFERRALS.md
-- Phase B. Same net.http_post + x-cron-secret pattern as video-cleanup.
select cron.schedule(
  'referral-qualify-daily',
  '0 13 * * *',
  format(
    $cron$select net.http_post(
      url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/referral-qualify'::text,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', %L),
      body := '{}'::jsonb
    )$cron$,
    (select value from public.app_config where key = 'cron_secret')
  )
);
