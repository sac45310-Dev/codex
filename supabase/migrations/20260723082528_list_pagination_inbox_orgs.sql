drop function if exists public.get_conversations();
create or replace function public.get_conversations(
  p_search text default null, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare v_tenant uuid := auth_tenant_id();
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  return coalesce((
    select jsonb_agg(c order by last_at desc) from (
      select jsonb_build_object(
        'donor_id', d.id, 'first_name', d.first_name, 'last_name', d.last_name,
        'phone_e164', d.phone_e164, 'consent_status', d.consent_status,
        'last_body', m.body, 'last_direction', m.direction, 'last_at', m.created_at,
        'unread', (select count(*) from messages u
          where u.tenant_id = v_tenant and u.donor_id = d.id
            and u.direction = 'inbound' and u.read_at is null)
      ) as c, m.created_at as last_at
      from donors d
      join lateral (
        select body, direction, created_at from messages
        where tenant_id = v_tenant and donor_id = d.id
        order by created_at desc limit 1
      ) m on true
      where d.tenant_id = v_tenant and d.status <> 'deleted'
        and (p_search is null or p_search = ''
             or (coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')) ilike '%'||p_search||'%'
             or coalesce(d.phone_e164, '') ilike '%'||p_search||'%')
      order by m.created_at desc
      limit least(p_limit, 100) offset p_offset
    ) sub
  ), '[]'::jsonb);
end $function$;

create or replace function public.get_unread_total()
returns integer language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(count(*), 0)::int from messages
  where tenant_id = auth_tenant_id() and direction = 'inbound' and read_at is null;
$function$;

drop function if exists public.admin_list_tenants();
create or replace function public.admin_list_tenants(
  p_search text default null, p_limit int default 25, p_offset int default 0)
returns table(id uuid, legal_name text, created_at timestamptz, onboarded_at timestamptz,
  subscription_status text, plan text, billing_mode text, suspended_at timestamptz,
  current_period_end timestamptz, user_count bigint, donor_count bigint,
  grant_expires timestamptz, last_activity timestamptz, errors_7d bigint, total_count bigint)
language plpgsql stable security definer set search_path to 'public'
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
    where p_search is null or p_search = '' or t.legal_name ilike '%'||p_search||'%'
  ), counted as (
    select b.*, count(*) over () as total_count from base b
  )
  select c.id, c.legal_name, c.created_at, c.onboarded_at, c.subscription_status,
         c.plan, c.billing_mode, c.suspended_at, c.current_period_end, c.user_count,
         c.donor_count, c.grant_expires, c.last_activity, c.errors_7d, c.total_count
  from counted c
  order by c.created_at desc
  limit least(p_limit, 100) offset p_offset;
end $function$;
