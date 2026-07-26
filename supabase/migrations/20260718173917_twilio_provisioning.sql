-- ============ Phase 4: zero-touch Twilio provisioning =======================
-- BILLING.md Phase 4. Design follows the 2026 Twilio ISV best practices
-- researched for BILLING.md:
--  * subaccount per tenant  — Twilio's recommended ISV pattern: isolation,
--    per-tenant usage billing, blast-radius containment
--  * registration reflects the NONPROFIT's identity (their legal name, EIN,
--    their opt-in story) — a carrier compliance requirement, not a choice
--  * resumable state machine — every Twilio SID is persisted the moment it
--    exists, so any step can retry idempotently and a missed webhook can
--    never strand an org
--  * cost-plus pricing lives in an admin-editable `addons` row (product
--    owner requirement: platform cost + adjustable premium, margin visible)

-- 1. Add-on catalog (cost-plus, admin-adjustable). --------------------------
create table public.addons (
  id text primary key,               -- 'twilio_number'
  name text not null,
  price_monthly_cents integer not null,     -- what the CUSTOMER pays
  setup_fee_cents integer not null default 0, -- one-time; 0 = included
  est_cost_monthly_cents integer,    -- OUR recurring cost (margin reporting)
  est_cost_setup_cents integer,      -- OUR one-time cost
  stripe_price_monthly text,         -- live lane
  stripe_price_monthly_test text,    -- sandbox lane
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.addons enable row level security;
create policy addons_read on public.addons for select to authenticated using (true);

insert into public.addons (id, name, price_monthly_cents, setup_fee_cents,
  est_cost_monthly_cents, est_cost_setup_cents,
  stripe_price_monthly, stripe_price_monthly_test) values
  ('twilio_number', 'Private texting number', 1500, 0, 415, 2000,
   'price_1TucBvLVblefTO2cFwqfJmft', 'price_1TucBuLCtmBOcsrVoS83apRu');
  -- est costs: ~$1.15 number + ~$1.50-3 campaign monthly; ~$20 one-time
  -- registration fees (Low-Volume lane). See BILLING.md research.

create or replace function public.admin_set_addon(p_id text, p_config jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'billing') then
    raise exception 'Not authorized';
  end if;
  update addons set
    price_monthly_cents = coalesce((p_config->>'price_monthly_cents')::int, price_monthly_cents),
    setup_fee_cents = coalesce((p_config->>'setup_fee_cents')::int, setup_fee_cents),
    est_cost_monthly_cents = coalesce((p_config->>'est_cost_monthly_cents')::int, est_cost_monthly_cents),
    est_cost_setup_cents = coalesce((p_config->>'est_cost_setup_cents')::int, est_cost_setup_cents),
    is_active = coalesce((p_config->>'is_active')::boolean, is_active),
    updated_at = now()
    where id = p_id;
  perform log_platform_event(null, 'addon_config', p_id || ' ' || p_config::text);
end $$;
revoke execute on function public.admin_set_addon(text, jsonb) from public, anon;

-- 2. Provisioning state machine: one row per NUMBER. ------------------------
-- status flow:
--   draft → subaccount → number_reserved → profile_pending → brand_pending
--         → brand_approved → campaign_pending → active
--   plus: rejected (machine-readable reason, resumable after fix),
--         grace (tenant left Launch; sending off, number held 30 days),
--         released (number returned to Twilio; terminal)
create table public.sms_provisioning (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  status text not null default 'draft' check (status in
    ('draft', 'subaccount', 'number_reserved', 'profile_pending',
     'brand_pending', 'brand_approved', 'campaign_pending', 'active',
     'rejected', 'grace', 'released')),
  business_info jsonb not null default '{}'::jsonb, -- EIN, legal name, rep…
  twilio_subaccount_sid text,
  phone_number text,                 -- E.164, shown the moment it's reserved
  phone_sid text,
  trust_profile_sid text,            -- TrustHub Secondary Customer Profile
  a2p_profile_sid text,              -- A2P Trust Product
  brand_sid text,
  campaign_sid text,
  messaging_service_sid text,
  rejection_reason text,
  grace_started_at timestamptz,
  stripe_item_id text,               -- the $15/mo subscription item
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index sms_provisioning_tenant_idx on public.sms_provisioning (tenant_id);
create index sms_provisioning_status_idx on public.sms_provisioning (status);

alter table public.sms_provisioning enable row level security;
-- Tenant admins can WATCH their provisioning (status page); all writes go
-- through the twilio-provision function (service role) — the state machine
-- must never be client-mutable.
create policy provisioning_own_read on public.sms_provisioning
  for select using (
    tenant_id = auth_tenant_id() and coalesce(tenant_role(), '') = 'admin');

-- 3. Tenant flag for cheap client gating. -----------------------------------
-- (Set/cleared only by the provisioning function + plan-change webhook.)
alter table public.tenants add column twilio_ready boolean not null default false;

-- Add to the protected billing columns: org admins must not flip this.
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
     or new.referral_code_used  is distinct from old.referral_code_used
     or new.twilio_ready        is distinct from old.twilio_ready then
    raise exception 'Billing fields are managed by DonorSend and cannot be edited directly.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

-- 4. Daily provisioning poll (webhook backstop). ----------------------------
-- Callbacks can be missed; a stuck org is unacceptable in a zero-touch
-- flow, so pending registrations are re-polled daily.
select cron.schedule(
  'twilio-provision-poll-daily',
  '30 13 * * *',
  format(
    $cron$select net.http_post(
      url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/twilio-provision'::text,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', %L),
      body := '{"action":"poll"}'::jsonb
    )$cron$,
    (select value from public.app_config where key = 'cron_secret')
  )
);
