-- ============ Console v2: least-privilege roles + ops visibility ===========
-- Best-practice pass on the staff console (BUILDLOG 2026-07-18):
--  * ROLE MATRIX TIGHTENED — support handles orgs/shadow/notes but cannot
--    move money or change plans (least privilege; previously all staff
--    could comp orgs). billing+owner keep money powers; owner keeps staff
--    management. All still audit-logged, all still coalesce-guarded.
--  * OPS RPCS — windows onto things that already run headless: the Twilio
--    provisioning queue, cancellation survey answers, client errors, and
--    whether last night's cron jobs actually ran.
--  * GLOBAL USER SEARCH — find any user by email/name across orgs
--    (support's most-used tool in any SaaS back office).

-- 1. Money actions: owner/billing only (support removed). ------------------
create or replace function admin_set_billing(p_tenant_id uuid, p_action text, p_days int default 14)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  if p_action = 'comp' then
    update tenants set subscription_status = 'active', plan = 'comped', current_period_end = null
      where id = p_tenant_id;
  elsif p_action = 'uncomp' then
    update tenants set subscription_status = 'none', plan = null where id = p_tenant_id;
  elsif p_action = 'extend_trial' then
    if p_days < 1 or p_days > 90 then raise exception 'Extension must be 1-90 days'; end if;
    update tenants set subscription_status = 'trialing',
      current_period_end = greatest(coalesce(current_period_end, now()), now()) + make_interval(days => p_days)
      where id = p_tenant_id;
  elsif p_action = 'lane_test' then
    update tenants set billing_mode = 'test' where id = p_tenant_id;
  elsif p_action = 'lane_live' then
    update tenants set billing_mode = 'live' where id = p_tenant_id;
  else
    raise exception 'Unknown action %', p_action;
  end if;
  perform log_platform_event(p_tenant_id, 'billing_' || p_action,
    case when p_action = 'extend_trial' then p_days || ' days' end);
end $$;

-- 2. Twilio provisioning queue. ---------------------------------------------
create or replace function public.admin_list_provisioning()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id,
      'org', t.legal_name,
      'status', p.status,
      'phone_number', p.phone_number,
      'rejection_reason', p.rejection_reason,
      'grace_started_at', p.grace_started_at,
      'updated_at', p.updated_at
    ) order by p.updated_at desc)
    from sms_provisioning p
    left join tenants t on t.id = p.tenant_id
  ), '[]'::jsonb);
end $$;

-- 3. Recent client errors (triage list behind the errors_7d stat tile). -----
create or replace function public.admin_recent_errors(p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(e order by (e->>'created_at') desc) from (
      select jsonb_build_object(
        'message', left(ce.message, 300),
        'url', ce.url,
        'org', t.legal_name,
        'created_at', ce.created_at
      ) as e
      from client_errors ce
      left join tenants t on t.id = ce.tenant_id
      order by ce.created_at desc
      limit least(p_limit, 200)
    ) sub
  ), '[]'::jsonb);
end $$;

-- 4. Cron health: did the nightly machinery actually run? -------------------
create or replace function public.admin_cron_health()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'job', j.jobname,
      'schedule', j.schedule,
      'active', j.active,
      'last_status', d.status,
      'last_run', d.start_time
    ) order by j.jobname)
    from cron.job j
    left join lateral (
      select status, start_time from cron.job_run_details
      where jobid = j.jobid order by start_time desc limit 1
    ) d on true
  ), '[]'::jsonb);
end $$;

-- 5. Global user search (email or name, across all orgs). -------------------
create or replace function public.admin_find_user(p_query text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', u.id, 'name', u.name, 'email', u.email, 'role', u.role,
      'tenant_id', u.tenant_id,
      'org', t.legal_name,
      'created_at', u.created_at
    ) order by u.created_at desc)
    from (
      select * from users
      where email ilike '%' || p_query || '%'
         or name ilike '%' || p_query || '%'
      limit 25
    ) u
    left join tenants t on t.id = u.tenant_id
  ), '[]'::jsonb);
end $$;

revoke execute on function public.admin_list_provisioning() from public, anon;
revoke execute on function public.admin_recent_errors(int) from public, anon;
revoke execute on function public.admin_cron_health() from public, anon;
revoke execute on function public.admin_find_user(text) from public, anon;
