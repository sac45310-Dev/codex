-- ============ Referral program (Phase A) ===================================
-- Account-level referrals: each tenant gets a code; a net-new tenant that
-- applies it gets attributed. Qualification (60 days continuously paid) and
-- reward issuance are Phase B (Stripe webhook + pg_cron) — this migration
-- lays the full schema so Phase A starts capturing attributions now.
-- Spec: REFERRALS.md.

-- 1. Global program config (singleton row, service/definer access only). ----
create table public.referral_program (
  id boolean primary key default true check (id), -- forces a single row
  enabled boolean not null default false,         -- master switch
  referrer_reward_type text not null default 'free_month'
    check (referrer_reward_type in ('free_month', 'fixed_credit', 'percent_off')),
  referrer_reward_scope text not null default 'base_fee', -- excludes pass-through (Twilio)
  qualify_days integer not null default 60 check (qualify_days between 1 and 365),
  require_continuous_paid boolean not null default true,
  new_customer_discount_type text not null default 'percent'
    check (new_customer_discount_type in ('percent', 'fixed')),
  new_customer_discount_value numeric not null default 25,
  stacking_mode text not null default 'per_cycle'
    check (stacking_mode in ('per_cycle', 'capped', 'single')),
  stacking_cap integer,                           -- null = unlimited
  net_new_max_account_age_days integer not null default 30,
  fraud_hold_on_shared_payment boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
insert into public.referral_program (id) values (true);
-- RLS on, no policies: readable/writable only via security-definer RPCs and
-- the service role (same posture as app_config).
alter table public.referral_program enable row level security;

-- 2. Tenant columns. --------------------------------------------------------
-- referrals_enabled: per-tenant kill switch (super admin can bar one org).
-- referral_code: the org's shareable code, generated lazily on first view.
-- referred_by_tenant_id / referral_code_used: attribution, set once.
-- NB: donors.referred_by (donor-referred-by-donor) is unrelated.
alter table public.tenants
  add column referrals_enabled boolean not null default true,
  add column referral_code text unique,
  add column referred_by_tenant_id uuid references public.tenants(id) on delete set null,
  add column referral_code_used text;

-- 3. Referral tracking spine: one row per referred tenant. ------------------
create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_tenant_id uuid not null references public.tenants(id) on delete cascade,
  referred_tenant_id uuid not null unique references public.tenants(id) on delete cascade,
  code text not null,
  status text not null default 'attributed' check (status in
    ('attributed', 'qualifying', 'qualified', 'rewarded', 'disqualified', 'void')),
  first_paid_at timestamptz,      -- starts the qualify clock (Phase B webhook)
  qualified_at timestamptz,
  rewarded_at timestamptz,
  disqualified_at timestamptz,
  disqualified_reason text,
  flagged boolean not null default false, -- fraud hold (Phase C)
  flag_reason text,
  created_at timestamptz not null default now()
);
create index referrals_referrer_idx on public.referrals (referrer_tenant_id);

-- 4. Rewards: one row per free month earned (stacking = many rows). ---------
create table public.referral_rewards (
  id uuid primary key default gen_random_uuid(),
  referral_id uuid not null references public.referrals(id) on delete cascade,
  referrer_tenant_id uuid not null references public.tenants(id) on delete cascade,
  reward_type text not null default 'free_month',
  amount_cents integer,           -- referrer base-fee snapshot at reward time
  currency text not null default 'USD',
  status text not null default 'accrued' check (status in
    ('accrued', 'applied', 'consumed', 'voided')),
  stripe_balance_txn_id text,     -- Stripe customer-balance credit (Phase B)
  idempotency_key text unique,    -- webhook/cron retries can't double-credit
  applied_at timestamptz,
  created_at timestamptz not null default now()
);
create index referral_rewards_referrer_idx on public.referral_rewards (referrer_tenant_id);

-- 5. Append-only audit trail (same trust story as consent_events). ----------
-- RLS on, no policies: clients can neither read nor write; security-definer
-- RPCs and the service role write, nothing updates or deletes.
create table public.referral_events (
  id bigint generated always as identity primary key,
  referral_id uuid references public.referrals(id) on delete set null,
  tenant_id uuid,                 -- acting/affected tenant (attempts log here)
  event_type text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);
create index referral_events_tenant_idx on public.referral_events (tenant_id, event_type, created_at);
alter table public.referral_events enable row level security;
revoke update, delete on public.referral_events from anon, authenticated;

-- 6. RLS for the tenant-facing tables. --------------------------------------
-- Referrers can SELECT their own rows; nobody writes from the client — all
-- mutations go through security-definer RPCs or the service role.
alter table public.referrals enable row level security;
alter table public.referral_rewards enable row level security;
create policy referrer_sel on public.referrals
  for select using (referrer_tenant_id = auth_tenant_id());
create policy referrer_sel on public.referral_rewards
  for select using (referrer_tenant_id = auth_tenant_id());

-- 7. Code generation (definer-internal helper). -----------------------------
-- 8 chars, alphabet drops 0/O/1/I to stay phone-dictation friendly.
create or replace function public.generate_referral_code()
returns text language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * 32)::int, 1), '')
      into v_code from generate_series(1, 8);
    exit when not exists (select 1 from tenants where referral_code = v_code);
  end loop;
  return v_code;
end $$;
revoke execute on function public.generate_referral_code() from public, anon, authenticated;

-- 8. get_referrals(): everything the Settings → Referrals page needs. -------
-- Tenant-admin only. Generates the org's code on first call (lazy, so we
-- don't backfill codes for orgs that never open the page).
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
    update tenants set referral_code = v_code where id = v_tenant;
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
revoke execute on function public.get_referrals() from public, anon;

-- 9. apply_referral_code(): attribution at onboarding. ----------------------
-- Called by the NEW tenant's admin. Validates hard (self-referral, net-new
-- only, one attribution ever) and rate-limits via the events table. Returns
-- the new-customer perk so the UI can confirm what they'll get.
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

  -- Rate limit: 10 failed attempts per hour per tenant.
  if (select count(*) from referral_events
      where tenant_id = v_tenant and event_type = 'code_attempt_failed'
        and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many attempts — please try again later.';
  end if;

  select * into v_me from tenants where id = v_tenant;
  if v_me.referred_by_tenant_id is not null then
    raise exception 'A referral code has already been applied to this account.';
  end if;
  -- Net-new only: young account that has never held a paid subscription.
  if v_me.created_at < now() - make_interval(days => v_prog.net_new_max_account_age_days)
     or v_me.stripe_subscription_id is not null
     or coalesce(v_me.subscription_status, 'none') not in ('none', 'trialing') then
    raise exception 'Referral codes are only for new accounts.';
  end if;

  select * into v_referrer from tenants
    where referral_code = v_code and referrals_enabled;
  -- One opaque error for bad code AND self-referral (no code enumeration).
  if v_referrer.id is null or v_referrer.id = v_tenant then
    insert into referral_events (tenant_id, event_type, detail)
      values (v_tenant, 'code_attempt_failed', jsonb_build_object('code', v_code));
    raise exception 'That code isn''t valid.';
  end if;

  update tenants
    set referred_by_tenant_id = v_referrer.id, referral_code_used = v_code
    where id = v_tenant;
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
revoke execute on function public.apply_referral_code(text) from public, anon;

-- 10. Console RPCs. ---------------------------------------------------------
-- Guard with coalesce(platform_role(),'') — bare "not in" is NULL for
-- non-staff and the raise never fires (hard rule, caught in QA).
create or replace function public.admin_get_referral_program()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return jsonb_build_object(
    'config', (select to_jsonb(rp) from referral_program rp where id),
    'stats', (select jsonb_build_object(
      'attributed', count(*) filter (where status = 'attributed'),
      'qualifying', count(*) filter (where status = 'qualifying'),
      'qualified', count(*) filter (where status = 'qualified'),
      'rewarded', count(*) filter (where status = 'rewarded'),
      'disqualified', count(*) filter (where status = 'disqualified'),
      'flagged', count(*) filter (where flagged)
    ) from referrals),
    'credited_cents', (select coalesce(sum(amount_cents), 0)
      from referral_rewards where status in ('applied', 'consumed'))
  );
end $$;

-- Owner/billing tune the program; support can only look.
create or replace function public.admin_set_referral_config(p_config jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  update referral_program set
    enabled = coalesce((p_config->>'enabled')::boolean, enabled),
    qualify_days = coalesce((p_config->>'qualify_days')::int, qualify_days),
    new_customer_discount_type = coalesce(p_config->>'new_customer_discount_type', new_customer_discount_type),
    new_customer_discount_value = coalesce((p_config->>'new_customer_discount_value')::numeric, new_customer_discount_value),
    referrer_reward_type = coalesce(p_config->>'referrer_reward_type', referrer_reward_type),
    stacking_cap = case when p_config ? 'stacking_cap'
      then (p_config->>'stacking_cap')::int else stacking_cap end,
    net_new_max_account_age_days = coalesce((p_config->>'net_new_max_account_age_days')::int, net_new_max_account_age_days),
    fraud_hold_on_shared_payment = coalesce((p_config->>'fraud_hold_on_shared_payment')::boolean, fraud_hold_on_shared_payment),
    updated_at = now(),
    updated_by = auth.uid()
    where id;
  perform log_platform_event(null, 'referral_config', p_config::text);
end $$;

create or replace function public.admin_set_tenant_referrals(p_tenant_id uuid, p_enabled boolean)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  update tenants set referrals_enabled = p_enabled where id = p_tenant_id;
  perform log_platform_event(p_tenant_id,
    case when p_enabled then 'referrals_enable' else 'referrals_disable' end, null);
end $$;

revoke execute on function public.admin_get_referral_program() from public, anon;
revoke execute on function public.admin_set_referral_config(jsonb) from public, anon;
revoke execute on function public.admin_set_tenant_referrals(uuid, boolean) from public, anon;

-- 11. Tenant detail gains referral fields (for the console toggle + context).
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
