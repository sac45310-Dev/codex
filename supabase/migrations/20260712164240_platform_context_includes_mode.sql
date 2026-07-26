create or replace function get_platform_context() returns json
language sql stable security definer set search_path to 'public' as $$
  select case when platform_role() is null then null else json_build_object(
    'role', platform_role(),
    'shadow', (
      select json_build_object(
        'tenant_id', t.id, 'legal_name', t.legal_name,
        'is_override', s.is_override, 'started_at', s.started_at,
        'mode', s.mode,
        'locale', t.locale, 'currency', t.currency,
        'donation_url', t.donation_url
      )
      from support_sessions s join tenants t on t.id = s.tenant_id
      where s.tenant_id = active_shadow_tenant()
        and s.staff_user_id = auth.uid() and s.ended_at is null
      order by s.started_at desc limit 1
    )
  ) end
$$;
