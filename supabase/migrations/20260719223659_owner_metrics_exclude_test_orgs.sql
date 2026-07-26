-- Exclude fixture + sandbox orgs (any @test.internal user) from the owner
-- report so the numbers reflect REAL customers only.
create or replace function public.owner_metrics()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $$
declare wk interval := interval '7 days';
begin
  if coalesce(platform_role(),'') not in ('owner','support','billing')
     and auth.role() <> 'service_role' then
    raise exception 'Not authorized';
  end if;
  return (
    with real_t as (
      select t.* from tenants t
      where not exists (
        select 1 from users u where u.tenant_id = t.id and u.email ilike '%@test.internal')
    )
    select jsonb_build_object(
      'signups_7d', (select count(*) from real_t where created_at > now()-wk),
      'signups_prev_7d', (select count(*) from real_t
          where created_at > now()-2*wk and created_at <= now()-wk),
      'total_orgs', (select count(*) from real_t where onboarded_at is not null),
      'activated_orgs', (select count(distinct d.tenant_id) from donors d
          join real_t rt on rt.id = d.tenant_id),
      'paying_orgs', (select count(*) from real_t
          where subscription_status in ('active','trialing') and plan_id <> 'free'),
      'trialing', (select count(*) from real_t where subscription_status='trialing'),
      'canceled_7d', (select count(*) from real_t
          where subscription_status='canceled' and current_period_end > now()-wk),
      'mrr_cents', (select coalesce(sum(p.price_monthly_cents),0)
          from real_t t join plans p on p.id=t.plan_id
          where t.subscription_status in ('active','trialing') and t.plan_id<>'free'),
      'open_errors', (select count(*) from error_groups where status='open'),
      'top_errors', (select coalesce(jsonb_agg(e), '[]'::jsonb) from (
          select jsonb_build_object('message', left(message_sample,120),
                 'count', event_count, 'source', source) as e
          from error_groups where status='open'
          order by last_seen desc limit 5) s),
      'digest_subscribers', (select count(*) from users where digest_opt_out=false
          and email not ilike '%@test.internal')
    )
  );
end $$;
