insert into public.app_config (key, value) values
  ('enrich_paused', 'on'),
  ('enrich_model', 'claude-sonnet-5'),
  ('enrich_batch', '2'),
  ('enrich_min_fit', '0')
on conflict (key) do nothing;

select cron.schedule(
  'contact-enrich',
  '*/5 * * * *',
  $cron$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/contact-enrich',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $cron$
);
