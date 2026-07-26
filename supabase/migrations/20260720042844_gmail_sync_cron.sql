select cron.schedule(
  'gmail-sync',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/gmail-sync',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
