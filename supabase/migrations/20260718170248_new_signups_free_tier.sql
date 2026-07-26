-- Phase 2 flip: NEW signups land on the Free tier and walk into the app
-- (no forced paywall); the plan picker is shown once, skippably. Existing
-- tenants stay exactly where they are (legacy_29_v1 / comped) and are
-- stamped plan_picked_at so they never see the onboarding picker.
alter table public.tenants
  alter column plan_id set default 'free',
  add column plan_picked_at timestamptz;

update tenants set plan_picked_at = now();

-- Tenant admins may stamp their own picker choice (Continue with Free).
-- (plan_id itself is never client-writable; only webhooks/functions set it.)

-- Billing-bearing tenant columns must not be client-writable: RLS is
-- row-level, not column-level, so without this an org admin could
-- `update tenants set plan_id='launch_v1'` (or subscription_status —
-- a pre-existing hole this also closes). Writers allowed through:
--   - service role (webhooks, edge functions): auth.uid() is null
--   - platform staff RPCs (admin_set_billing etc.): platform_role() set
create or replace function public.protect_billing_columns()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null or platform_role() is not null
     or coalesce(current_setting('app.system_write', true), '') = 'on' then
    return new; -- service role, platform staff, or our own definer RPCs
  end if;
  if new.plan_id                is distinct from old.plan_id
     or new.scheduled_plan_id   is distinct from old.scheduled_plan_id
     or new.scheduled_change_at is distinct from old.scheduled_change_at
     or new.trial_ends_at       is distinct from old.trial_ends_at
     or new.grandfathered_until is distinct from old.grandfathered_until
     or new.subscription_status is distinct from old.subscription_status
     or new.stripe_customer_id  is distinct from old.stripe_customer_id
     or new.stripe_subscription_id is distinct from old.stripe_subscription_id
     or new.plan                is distinct from old.plan
     or new.current_period_end  is distinct from old.current_period_end
     or new.billing_mode        is distinct from old.billing_mode
     or new.suspended_at        is distinct from old.suspended_at
     or new.referrals_enabled   is distinct from old.referrals_enabled
     or new.referral_code       is distinct from old.referral_code
     or new.referred_by_tenant_id is distinct from old.referred_by_tenant_id
     or new.referral_code_used  is distinct from old.referral_code_used then
    raise exception 'Billing fields are managed by DonorSend and cannot be edited directly.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger trg_protect_billing_columns
  before update on public.tenants
  for each row execute function public.protect_billing_columns();

-- Our own security-definer RPCs that write protected columns on behalf of
-- tenant users set app.system_write around their updates.
-- get_referrals: lazy referral-code generation.
create or replace function public.get_referrals()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_tenant uuid := auth_tenant_id();
  v_prog referral_program;
  v_code text;
  v_tenant_enabled boolean;
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  if coalesce(tenant_role(), '') <> 'admin' then
    raise exception 'Not authorized';
  end if;

  select * into v_prog from referral_program where id;
  select referrals_enabled, referral_code into v_tenant_enabled, v_code
    from tenants where id = v_tenant;

  if not (v_prog.enabled and v_tenant_enabled) then
    return jsonb_build_object('enabled', false);
  end if;

  if v_code is null then
    v_code := generate_referral_code();
    perform set_config('app.system_write', 'on', true);
    update tenants set referral_code = v_code where id = v_tenant;
    perform set_config('app.system_write', '', true);
    insert into referral_events (tenant_id, event_type)
      values (v_tenant, 'code_generated');
  end if;

  return jsonb_build_object(
    'enabled', true,
    'code', v_code,
    'offer', jsonb_build_object(
      'qualify_days', v_prog.qualify_days,
      'reward_type', v_prog.referrer_reward_type,
      'discount_type', v_prog.new_customer_discount_type,
      'discount_value', v_prog.new_customer_discount_value
    ),
    'referrals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'org_name', t.legal_name,
        'status', r.status,
        'created_at', r.created_at,
        'first_paid_at', r.first_paid_at,
        'qualified_at', r.qualified_at,
        'rewarded_at', r.rewarded_at
      ) order by r.created_at desc)
      from referrals r join tenants t on t.id = r.referred_tenant_id
      where r.referrer_tenant_id = v_tenant
    ), '[]'::jsonb),
    'rewards', (
      select jsonb_build_object(
        'earned_months', count(*) filter (where status <> 'voided'),
        'credited_cents', coalesce(sum(amount_cents)
          filter (where status in ('applied', 'consumed')), 0)
      )
      from referral_rewards where referrer_tenant_id = v_tenant
    )
  );
end $$;

-- apply_referral_code: writes referred_by_tenant_id / referral_code_used.
create or replace function public.apply_referral_code(p_code text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_tenant uuid := auth_tenant_id();
  v_prog referral_program;
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_me tenants;
  v_referrer tenants;
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  if coalesce(tenant_role(), '') <> 'admin' then
    raise exception 'Not authorized';
  end if;

  select * into v_prog from referral_program where id;
  if not v_prog.enabled then
    raise exception 'The referral program is not currently available.';
  end if;

  if (select count(*) from referral_events
      where tenant_id = v_tenant and event_type = 'code_attempt_failed'
        and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many attempts — please try again later.';
  end if;

  select * into v_me from tenants where id = v_tenant;
  if v_me.referred_by_tenant_id is not null then
    raise exception 'A referral code has already been applied to this account.';
  end if;
  if v_me.created_at < now() - make_interval(days => v_prog.net_new_max_account_age_days)
     or v_me.stripe_subscription_id is not null
     or coalesce(v_me.subscription_status, 'none') not in ('none', 'trialing') then
    raise exception 'Referral codes are only for new accounts.';
  end if;

  select * into v_referrer from tenants
    where referral_code = v_code and referrals_enabled;
  if v_referrer.id is null or v_referrer.id = v_tenant then
    insert into referral_events (tenant_id, event_type, detail)
      values (v_tenant, 'code_attempt_failed', jsonb_build_object('code', v_code));
    return jsonb_build_object('ok', false, 'error', 'That code isn''t valid.');
  end if;

  perform set_config('app.system_write', 'on', true);
  update tenants
    set referred_by_tenant_id = v_referrer.id, referral_code_used = v_code
    where id = v_tenant;
  perform set_config('app.system_write', '', true);
  insert into referrals (referrer_tenant_id, referred_tenant_id, code)
    values (v_referrer.id, v_tenant, v_code);
  insert into referral_events (referral_id, tenant_id, event_type, detail)
    select r.id, v_tenant, 'attributed',
           jsonb_build_object('referrer_tenant_id', v_referrer.id, 'code', v_code)
    from referrals r where r.referred_tenant_id = v_tenant;

  return jsonb_build_object(
    'ok', true,
    'referrer_org', v_referrer.legal_name,
    'discount_type', v_prog.new_customer_discount_type,
    'discount_value', v_prog.new_customer_discount_value
  );
end $$;
