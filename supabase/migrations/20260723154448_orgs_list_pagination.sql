drop function if exists public.admin_list_tenants();
drop function if exists public.admin_list_tenants(text, int, int);
create or replace function public.admin_list_tenants(
  p_search text default null, p_filter text default null,
  p_limit int default 25, p_offset int default 0)
returns table(id uuid, legal_name text, created_at timestamptz, onboarded_at timestamptz,
  subscription_status text, plan text, billing_mode text, suspended_at timestamptz,
  current_period_end timestamptz, user_count bigint, donor_count bigint,
  grant_expires timestamptz, last_activity timestamptz, errors_7d bigint, total_count bigint)
language plpgsql stable security definer
set search_path to 'public'
as $function$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  with base as (
    select t.id, t.legal_name, t.created_at, t.onboarded_at,
           t.subscription_status, t.plan, t.billing_mode, t.suspended_at,
           t.current_period_end,
           (select count(*) from users u where u.tenant_id = t.id) as user_count,
           (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active') as donor_count,
           (select max(g.expires_at) from support_grants g
             where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now()) as grant_expires,
           (select max(a.created_at) from activity_log a where a.tenant_id = t.id) as last_activity,
           (select count(*) from client_errors e
             where e.tenant_id = t.id and e.created_at > now() - interval '7 days') as errors_7d
    from tenants t
  ), flagged as (
    select b.*,
      (b.suspended_at is not null
       or (b.onboarded_at is null and b.created_at < now() - interval '30 days')
       or (b.subscription_status = 'trialing' and b.current_period_end is not null
           and b.current_period_end - now() < interval '3 days')
       or (b.onboarded_at is not null
           and (b.last_activity is null or b.last_activity < now() - interval '30 days'))
       or (b.onboarded_at is not null and b.donor_count = 0
           and b.created_at < now() - interval '7 days')
       or b.errors_7d > 0) as at_risk
    from base b
  ), matched as (
    select f.* from flagged f
    where (
        p_filter is null or p_filter = '' or p_filter = 'all'
        or (p_filter = 'test'      and f.billing_mode = 'test')
        or (p_filter = 'suspended' and f.suspended_at is not null)
        or (p_filter = 'stuck'     and f.onboarded_at is null and f.created_at < now() - interval '30 days')
        or (p_filter = 'at_risk'   and f.at_risk)
        or (p_filter not in ('all','test','suspended','stuck','at_risk')
            and coalesce(f.subscription_status, 'none') = p_filter)
      )
      and (p_search is null or p_search = '' or f.legal_name ilike '%'||p_search||'%')
  ), counted as (
    select m.*, count(*) over () as total_count from matched m
  )
  select c.id, c.legal_name, c.created_at, c.onboarded_at, c.subscription_status,
         c.plan, c.billing_mode, c.suspended_at, c.current_period_end, c.user_count,
         c.donor_count, c.grant_expires, c.last_activity, c.errors_7d, c.total_count
  from counted c
  order by c.created_at desc
  limit least(p_limit, 100) offset p_offset;
end $function$;
