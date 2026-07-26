-- Vercel deploy watchdog cron: every 10 min the vercel-deploy-check edge fn
-- looks at donor-crm's recent production deployments; failed/canceled ones
-- land in client_errors (→ existing error-alerts email). Soft-off inside the
-- fn until vercel_token exists in app_config. Born from the 2026-07-20
-- production 404 that was only noticed from a phone screenshot.
select cron.schedule(
  'vercel-deploy-watch',
  '*/10 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/vercel-deploy-check',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
