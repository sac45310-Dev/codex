select cron.schedule(
  'sales-daily-queue',
  '0 14 * * *',  -- 7:00am Pacific
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/sales-daily-queue',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
