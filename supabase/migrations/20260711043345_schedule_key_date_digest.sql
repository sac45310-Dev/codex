create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Shared secret the digest function checks
insert into public.app_config (key, value)
values ('cron_secret', gen_random_uuid()::text)
on conflict (key) do nothing;

-- Every Monday 15:00 UTC (= 7-8am Pacific)
select cron.schedule(
  'key-date-digest-weekly',
  '0 15 * * 1',
  format(
    $cron$select net.http_post(
      url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/twilio-inbound'::text,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', %L),
      body := '{}'::jsonb
    )$cron$,
    (select value from public.app_config where key = 'cron_secret')
  )
);
