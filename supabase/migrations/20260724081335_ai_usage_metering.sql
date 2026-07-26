create table if not exists public.ai_usage (
  id bigint generated always as identity primary key,
  fn text not null,
  tenant_id uuid,
  model text,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.ai_usage enable row level security;
create index if not exists ai_usage_created_at_idx on public.ai_usage (created_at);

insert into public.app_config (key, value) values
  ('ai_daily_token_alert_threshold', '2000000'),
  ('ai_usage_alert_last_sent', '')
on conflict (key) do nothing;

create or replace function public.admin_ai_usage_summary(p_hours int default 24)
returns table(fn text, calls bigint, input_tokens bigint, output_tokens bigint)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and coalesce(platform_role(), '') = '' then
    raise exception 'Not authorized';
  end if;
  return query
    select u.fn, count(*)::bigint,
           coalesce(sum(u.input_tokens), 0)::bigint,
           coalesce(sum(u.output_tokens), 0)::bigint
    from public.ai_usage u
    where u.created_at > now() - make_interval(hours => p_hours)
    group by u.fn
    order by 2 desc;
end $$;
revoke execute on function public.admin_ai_usage_summary(int) from public;
grant execute on function public.admin_ai_usage_summary(int) to authenticated;

select cron.schedule(
  'ai-usage-check',
  '0 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/ai-usage-check',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')
    ),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
