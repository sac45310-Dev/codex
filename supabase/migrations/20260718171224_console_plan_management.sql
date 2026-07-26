-- ============ Phase 3: console plan management ==============================
-- Staff RPCs for the /admin Plans tab + per-tenant plan/override controls,
-- and the customer cancellation-feedback table. All admin_* RPCs follow the
-- house rule: guard with coalesce(platform_role(),'') and log via
-- log_platform_event.

-- 1. Cancellation feedback (in-app cancel survey; BILLING.md Phase 3). -----
create table public.cancellation_feedback (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid,                    -- no FK: feedback survives org deletion
  tenant_name text,
  reason text not null,
  detail text,
  created_at timestamptz not null default now()
);
alter table public.cancellation_feedback enable row level security;
-- Tenant admins may insert their own feedback; only staff read it.
create policy feedback_ins on public.cancellation_feedback
  for insert with check (
    tenant_id = auth_tenant_id() and coalesce(tenant_role(), '') = 'admin');
create policy feedback_staff_sel on public.cancellation_feedback
  for select using (platform_role() is not null);

-- 2. Plans list for the console. --------------------------------------------
create or replace function public.admin_list_plans()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'blurb', p.blurb,
      'price_monthly_cents', p.price_monthly_cents,
      'price_annual_cents', p.price_annual_cents,
      'trial_days', p.trial_days,
      'is_public', p.is_public, 'is_active_for_new', p.is_active_for_new,
      'sort', p.sort,
      'has_stripe', p.stripe_price_monthly is not null,
      'subscribers', (select count(*) from tenants t where t.plan_id = p.id),
      'entitlements', (select jsonb_object_agg(pe.feature_key,
          jsonb_build_object('bool', pe.bool_value, 'limit', pe.limit_value))
        from plan_entitlements pe where pe.plan_id = p.id)
    ) order by p.sort, p.id)
    from plans p
  ), '[]'::jsonb);
end $$;

-- 3. In-place plan edit (the deliberate path through the version guard). ----
-- Only entitlements / trial / name / blurb — never prices (Stripe prices
-- are immutable; price changes REQUIRE a new version).
create or replace function public.admin_edit_plan_inplace(p_plan_id text, p_config jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
declare k text; v jsonb;
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  perform set_config('app.allow_plan_edit', 'on', true);
  update plans set
    name = coalesce(p_config->>'name', name),
    blurb = coalesce(p_config->>'blurb', blurb),
    trial_days = coalesce((p_config->>'trial_days')::int, trial_days)
    where id = p_plan_id;
  for k, v in select * from jsonb_each(coalesce(p_config->'entitlements', '{}'::jsonb)) loop
    insert into plan_entitlements (plan_id, feature_key, bool_value, limit_value)
    values (p_plan_id, k,
      case when v ? 'bool' then (v->>'bool')::boolean end,
      case when v ? 'limit' and v->>'limit' is not null then (v->>'limit')::numeric end)
    on conflict (plan_id, feature_key) do update set
      bool_value = excluded.bool_value,
      limit_value = excluded.limit_value;
  end loop;
  perform set_config('app.allow_plan_edit', '', true);
  perform log_platform_event(null, 'plan_edit_inplace',
    p_plan_id || ' ' || p_config::text);
end $$;

-- 4. Manually move ONE tenant to a plan (comp, migration, support fix). -----
create or replace function public.admin_set_tenant_plan(
  p_tenant_id uuid, p_plan_id text, p_reason text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required';
  end if;
  if not exists (select 1 from plans where id = p_plan_id) then
    raise exception 'Unknown plan %', p_plan_id;
  end if;
  update tenants set plan_id = p_plan_id where id = p_tenant_id;
  perform log_platform_event(p_tenant_id, 'plan_set_manual',
    p_plan_id || ' — ' || p_reason);
end $$;

-- 5. Per-tenant entitlement overrides. --------------------------------------
create or replace function public.admin_set_entitlement_override(
  p_tenant_id uuid, p_key text, p_bool boolean, p_limit numeric,
  p_reason text, p_expires timestamptz default null)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required';
  end if;
  insert into tenant_entitlement_overrides
    (tenant_id, feature_key, bool_value, limit_value, reason, created_by, expires_at)
  values (p_tenant_id, p_key, p_bool, p_limit, p_reason, auth.uid(), p_expires)
  on conflict (tenant_id, feature_key) do update set
    bool_value = excluded.bool_value,
    limit_value = excluded.limit_value,
    reason = excluded.reason,
    created_by = excluded.created_by,
    created_at = now(),
    expires_at = excluded.expires_at;
  perform log_platform_event(p_tenant_id, 'entitlement_override',
    p_key || '=' || coalesce(p_bool::text, coalesce(p_limit::text, 'unlimited'))
    || ' — ' || p_reason);
end $$;

create or replace function public.admin_clear_entitlement_override(
  p_tenant_id uuid, p_key text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  delete from tenant_entitlement_overrides
    where tenant_id = p_tenant_id and feature_key = p_key;
  perform log_platform_event(p_tenant_id, 'entitlement_override_cleared', p_key);
end $$;

revoke execute on function public.admin_list_plans() from public, anon;
revoke execute on function public.admin_edit_plan_inplace(text, jsonb) from public, anon;
revoke execute on function public.admin_set_tenant_plan(uuid, text, text) from public, anon;
revoke execute on function public.admin_set_entitlement_override(uuid, text, boolean, numeric, text, timestamptz) from public, anon;
revoke execute on function public.admin_clear_entitlement_override(uuid, text) from public, anon;

-- 6. Tenant detail v3: plan + overrides for the console. --------------------
create or replace function admin_tenant_detail(p_tenant_id uuid)
returns json language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
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
              order by ss.started_at desc limit 10) s), '[]'::json)
    )
    from tenants t where t.id = p_tenant_id
  );
end $$;
