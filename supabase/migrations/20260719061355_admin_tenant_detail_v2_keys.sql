-- Console v2 regression fix: the UI reads notes/activity/errors/events/
-- suspended_at from admin_tenant_detail but the deployed function predated
-- them → every org-detail open crashed ("undefined reading 'length'").
create or replace function public.admin_tenant_detail(p_tenant_id uuid)
returns json language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') = '' then raise exception 'Not authorized'; end if;
  return (
    select json_build_object(
      'id', t.id, 'legal_name', t.legal_name, 'created_at', t.created_at,
      'onboarded_at', t.onboarded_at, 'subscription_status', t.subscription_status,
      'plan', t.plan, 'billing_mode', t.billing_mode,
      'current_period_end', t.current_period_end,
      'city', t.city, 'state', t.state, 'ein', t.ein,
      'plan_id', t.plan_id,
      'plan_name', (select p.name from plans p where p.id = t.plan_id),
      'scheduled_plan_id', t.scheduled_plan_id,
      'suspended_at', t.suspended_at,
      'stripe_customer_id', t.stripe_customer_id,
      'overrides', coalesce((select json_agg(json_build_object(
          'feature_key', o.feature_key, 'bool_value', o.bool_value,
          'limit_value', o.limit_value, 'reason', o.reason,
          'expires_at', o.expires_at) order by o.feature_key)
        from tenant_entitlement_overrides o where o.tenant_id = t.id), '[]'::json),
      'referrals_enabled', t.referrals_enabled,
      'referral_code', t.referral_code,
      'referred_by', (select rt.legal_name from tenants rt
        where rt.id = t.referred_by_tenant_id),
      'referral_counts', (select json_build_object(
          'sent', count(*), 'rewarded', count(*) filter (where status = 'rewarded'))
        from referrals r where r.referrer_tenant_id = t.id),
      'donor_count', (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active'),
      'grant_expires', (select max(g.expires_at) from support_grants g
        where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now()),
      'users', coalesce((select json_agg(json_build_object(
          'id', u.id, 'name', u.name, 'email', u.email, 'role', u.role,
          'created_at', u.created_at) order by u.created_at)
        from users u where u.tenant_id = t.id), '[]'::json),
      'invitations', coalesce((select json_agg(json_build_object(
          'id', i.id, 'email', i.email, 'role', i.role, 'token', i.token,
          'created_at', i.created_at) order by i.created_at desc)
        from invitations i where i.tenant_id = t.id and i.accepted_at is null), '[]'::json),
      'sessions', coalesce((select json_agg(json_build_object(
          'id', s.id, 'started_at', s.started_at, 'ended_at', s.ended_at,
          'is_override', s.is_override, 'reason', s.reason) order by s.started_at desc)
        from (select * from support_sessions ss where ss.tenant_id = t.id
              order by ss.started_at desc limit 10) s), '[]'::json),
      'notes', coalesce((select json_agg(json_build_object(
          'id', n.id, 'body', n.body, 'author_id', n.author_id,
          'author_email', n.author_email, 'created_at', n.created_at)
          order by n.created_at desc)
        from platform_notes n where n.tenant_id = t.id), '[]'::json),
      'activity', coalesce((select json_agg(json_build_object(
          'action', a.action, 'detail', a.detail, 'created_at', a.created_at)
          order by a.created_at desc)
        from (select * from activity_log al where al.tenant_id = t.id
              order by al.created_at desc limit 15) a), '[]'::json),
      'errors', coalesce((select json_agg(json_build_object(
          'message', e.message, 'url', e.url, 'created_at', e.created_at)
          order by e.created_at desc)
        from (select * from client_errors ce where ce.tenant_id = t.id
              and ce.created_at > now() - interval '7 days'
              order by ce.created_at desc limit 15) e), '[]'::json),
      'events', coalesce((select json_agg(json_build_object(
          'action', pe.action, 'detail', pe.detail, 'created_at', pe.created_at)
          order by pe.created_at desc)
        from (select * from platform_events p2 where p2.tenant_id = t.id
              order by p2.created_at desc limit 15) pe), '[]'::json)
    )
    from tenants t where t.id = p_tenant_id
  );
end $$;
