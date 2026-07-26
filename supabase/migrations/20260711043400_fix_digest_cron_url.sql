-- Previous migration scheduled the wrong function URL; replace the job.
select cron.unschedule('key-date-digest-weekly');
select cron.schedule(
  'key-date-digest-weekly',
  '0 15 * * 1',
  format(
    $cron$select net.http_post(
      url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/key-date-digest'::text,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', %L),
      body := '{}'::jsonb
    )$cron$,
    (select value from public.app_config where key = 'cron_secret')
  )
);
select jobname, schedule, command from cron.job;
