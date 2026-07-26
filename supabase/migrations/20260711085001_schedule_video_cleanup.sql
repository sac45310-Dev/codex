-- Weekly video retention purge (Sundays 12:00 UTC)
select cron.schedule(
  'video-cleanup-weekly',
  '0 12 * * 0',
  format(
    $cron$select net.http_post(
      url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/video-cleanup'::text,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', %L),
      body := '{}'::jsonb
    )$cron$,
    (select value from public.app_config where key = 'cron_secret')
  )
);
select jobname, schedule from cron.job order by jobname;
