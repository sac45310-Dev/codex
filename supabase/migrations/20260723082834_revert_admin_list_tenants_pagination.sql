-- Revert admin_list_tenants to its original 0-arg form. The Orgs list has only
-- a handful of tenants and rich client-side filters (at_risk/stuck/etc.), so
-- server-side pagination isn't worth breaking those for; keep it as it was.
drop function if exists public.admin_list_tenants(text, int, int);
create or replace function public.admin_list_tenants()
returns table(id uuid, legal_name text, created_at timestamptz, onboarded_at timestamptz,
  subscription_status text, plan text, billing_mode text, suspended_at timestamptz,
  current_period_end timestamptz, user_count bigint, donor_count bigint,
  grant_expires timestamptz, last_activity timestamptz, errors_7d bigint)
language plpgsql stable security definer set search_path to 'public'
as $function$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  select t.id, t.legal_name, t.created_at, t.onboarded_at,
         t.subscription_status, t.plan, t.billing_mode, t.suspended_at,
         t.current_period_end,
         (select count(*) from users u where u.tenant_id = t.id),
         (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active'),
         (select max(g.expires_at) from support_grants g
           where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now()),
         (select max(a.created_at) from activity_log a where a.tenant_id = t.id),
         (select count(*) from client_errors e
           where e.tenant_id = t.id and e.created_at > now() - interval '7 days')
  from tenants t order by t.created_at desc;
end $function$;
