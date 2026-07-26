-- Increment a counter inside campaigns.stats jsonb (sent/opened/…).
create or replace function public.bump_campaign_stat(p_campaign uuid, p_key text)
returns void language sql security definer set search_path to 'public' as $$
  update campaigns
    set stats = jsonb_set(stats, array[p_key],
      to_jsonb(coalesce((stats->>p_key)::int, 0) + 1))
    where id = p_campaign;
$$;
revoke execute on function public.bump_campaign_stat(uuid, text) from public, anon, authenticated;

-- Fast unsubscribe-token lookup.
create index if not exists donors_email_unsub_idx on public.donors (email_unsub_token);

-- Email-sender cron (every 5 min).
select cron.schedule('email-sender', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/email-sender',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key='cron_secret')),
    body := '{"action":"cron"}'::jsonb);
$$);
