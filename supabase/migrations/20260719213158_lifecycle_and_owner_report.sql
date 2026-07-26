create table public.lifecycle_emails_sent (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  kind text not null,
  sent_at timestamptz not null default now(),
  primary key (tenant_id, kind)
);
alter table public.lifecycle_emails_sent enable row level security;

select cron.schedule(
  'lifecycle-emails',
  '25 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/lifecycle-emails',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key='cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);

select cron.schedule(
  'owner-weekly-report',
  '0 15 * * 1',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/owner-report',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key='cron_secret')),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);

create or replace function public.owner_metrics()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $$
declare wk interval := interval '7 days';
begin
  if coalesce(platform_role(),'') not in ('owner','support','billing')
     and current_setting('app.cron', true) <> 'on' then
    raise exception 'Not authorized';
  end if;
  return jsonb_build_object(
    'signups_7d', (select count(*) from tenants where created_at > now()-wk),
    'signups_prev_7d', (select count(*) from tenants
        where created_at > now()-2*wk and created_at <= now()-wk),
    'total_orgs', (select count(*) from tenants where onboarded_at is not null),
    'activated_orgs', (select count(distinct d.tenant_id) from donors d),
    'paying_orgs', (select count(*) from tenants
        where subscription_status in ('active','trialing') and plan_id <> 'free'),
    'trialing', (select count(*) from tenants where subscription_status='trialing'),
    'canceled_7d', (select count(*) from tenants
        where subscription_status='canceled' and current_period_end > now()-wk),
    'mrr_cents', (select coalesce(sum(p.price_monthly_cents),0)
        from tenants t join plans p on p.id=t.plan_id
        where t.subscription_status in ('active','trialing') and t.plan_id<>'free'),
    'open_errors', (select count(*) from error_groups where status='open'),
    'top_errors', (select coalesce(jsonb_agg(e), '[]'::jsonb) from (
        select jsonb_build_object('message', left(message_sample,120),
               'count', event_count, 'source', source) as e
        from error_groups where status='open'
        order by last_seen desc limit 5) s),
    'digest_subscribers', (select count(*) from users where digest_opt_out=false
        and email not ilike '%@test.internal')
  );
end $$;
