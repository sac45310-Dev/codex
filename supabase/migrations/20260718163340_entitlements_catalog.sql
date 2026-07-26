-- ============ Billing v2 Phase 1: entitlements catalog ======================
-- DB-driven plan catalog (BILLING.md): plans/limits/flags live as data so
-- pricing changes are catalog edits, not deploys. Supabase is the
-- entitlement brain; Stripe stays biller-only. Ships dark: every existing
-- tenant is backfilled to legacy_29_v1 (all-access, matches today's $29
-- plan), so nothing visible changes until Phase 2 flips new signups to the
-- four public tiers.

-- 1. Catalog tables. ---------------------------------------------------------
create table public.plans (
  id text primary key,              -- 'free','startup_v1','growth_v1','launch_v1','legacy_29_v1'
  name text not null,
  blurb text,
  price_monthly_cents integer not null default 0,
  price_annual_cents integer not null default 0,
  stripe_price_monthly text,        -- filled at Phase 2 go-live
  stripe_price_annual text,
  trial_days integer not null default 14,
  is_public boolean not null default false,       -- shown on paywall/pricing
  is_active_for_new boolean not null default false, -- false = legacy, still resolvable
  sort integer not null default 0
);

create table public.features (
  key text primary key,
  kind text not null check (kind in ('flag', 'limit')),
  description text
);

create table public.plan_entitlements (
  plan_id text not null references public.plans(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  bool_value boolean,
  limit_value numeric,              -- NULL = unlimited (for kind='limit')
  primary key (plan_id, feature_key)
);

-- Per-tenant exceptions (comps, one-off bumps). Audited via platform_events
-- when written from the console (Phase 3 RPCs); mandatory reason either way.
create table public.tenant_entitlement_overrides (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  bool_value boolean,
  limit_value numeric,
  reason text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  primary key (tenant_id, feature_key)
);

-- Catalog is readable by any signed-in user (the paywall needs plan cards);
-- writes only via service role / future admin RPCs. Overrides are
-- definer-read only.
alter table public.plans enable row level security;
alter table public.features enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.tenant_entitlement_overrides enable row level security;
create policy catalog_read on public.plans for select to authenticated using (true);
create policy catalog_read on public.features for select to authenticated using (true);
create policy catalog_read on public.plan_entitlements for select to authenticated using (true);
-- no policies on overrides: service-role/definer access only

-- 2. Tenant columns. ---------------------------------------------------------
-- Default legacy_29_v1 keeps new signups on the old all-access behavior
-- until Phase 2 switches the signup flow to the public tiers.
alter table public.tenants
  add column plan_id text not null default 'legacy_29_v1',
  add column trial_ends_at timestamptz,
  add column scheduled_plan_id text,
  add column scheduled_change_at timestamptz,
  add column grandfathered_until timestamptz;

-- 3. Seed the catalog. -------------------------------------------------------
insert into public.plans (id, name, blurb, price_monthly_cents, price_annual_cents,
  trial_days, is_public, is_active_for_new, sort) values
  ('free',         'Free',                  '1 sender · 10 supporters · unlimited texting', 0, 0, 0, true, true, 0),
  ('startup_v1',   'Start-Up',              '2 senders · 100 supporters · segments & custom fields', 1900, 19000, 14, true, true, 1),
  ('growth_v1',    'Organizational Growth', '5 senders · unlimited supporters · teams & analytics', 4900, 49000, 14, true, true, 2),
  ('launch_v1',    'Launch',                'Everything + private phone number via Twilio', 6900, 69000, 14, true, true, 3),
  ('legacy_29_v1', 'DonorSend (legacy)',    'Original all-access plan', 2900, 29000, 14, false, false, 99);

insert into public.features (key, kind, description) values
  ('seats.senders',   'limit', 'Users who can text (admin + sender roles)'),
  ('supporters.max',  'limit', 'Active donors in the system'),
  ('segments.custom', 'flag',  'Custom segments'),
  ('custom_fields',   'flag',  'Custom donor fields'),
  ('teams',           'flag',  'Assignments & team features'),
  ('analytics',       'flag',  'Team performance & analytics'),
  ('donations.page',  'flag',  'Hosted donation-collection page (future); manual gift entry is always available'),
  ('video_messages',  'flag',  'Personal video messages'),
  ('twilio.numbers',  'limit', 'Private Twilio numbers (Launch add-on)');

-- Matrix (BILLING.md). limit NULL = unlimited.
insert into public.plan_entitlements (plan_id, feature_key, bool_value, limit_value) values
  -- Free: capped ONLY by donors + 1 seat; full unlimited texting.
  ('free', 'seats.senders',   null, 1),
  ('free', 'supporters.max',  null, 10),
  ('free', 'segments.custom', false, null),
  ('free', 'custom_fields',   false, null),
  ('free', 'teams',           false, null),
  ('free', 'analytics',       false, null),
  ('free', 'donations.page',  false, null),
  ('free', 'video_messages',  true,  null),
  ('free', 'twilio.numbers',  null, 0),
  -- Start-Up
  ('startup_v1', 'seats.senders',   null, 2),
  ('startup_v1', 'supporters.max',  null, 100),
  ('startup_v1', 'segments.custom', true, null),
  ('startup_v1', 'custom_fields',   true, null),
  ('startup_v1', 'teams',           false, null),
  ('startup_v1', 'analytics',       false, null),
  ('startup_v1', 'donations.page',  true, null),
  ('startup_v1', 'video_messages',  true, null),
  ('startup_v1', 'twilio.numbers',  null, 0),
  -- Growth
  ('growth_v1', 'seats.senders',   null, 5),
  ('growth_v1', 'supporters.max',  null, null),
  ('growth_v1', 'segments.custom', true, null),
  ('growth_v1', 'custom_fields',   true, null),
  ('growth_v1', 'teams',           true, null),
  ('growth_v1', 'analytics',       true, null),
  ('growth_v1', 'donations.page',  true, null),
  ('growth_v1', 'video_messages',  true, null),
  ('growth_v1', 'twilio.numbers',  null, 0),
  -- Launch
  ('launch_v1', 'seats.senders',   null, null),
  ('launch_v1', 'supporters.max',  null, null),
  ('launch_v1', 'segments.custom', true, null),
  ('launch_v1', 'custom_fields',   true, null),
  ('launch_v1', 'teams',           true, null),
  ('launch_v1', 'analytics',       true, null),
  ('launch_v1', 'donations.page',  true, null),
  ('launch_v1', 'video_messages',  true, null),
  ('launch_v1', 'twilio.numbers',  null, null),
  -- Legacy $29: all-access (today's behavior, unchanged)
  ('legacy_29_v1', 'seats.senders',   null, null),
  ('legacy_29_v1', 'supporters.max',  null, null),
  ('legacy_29_v1', 'segments.custom', true, null),
  ('legacy_29_v1', 'custom_fields',   true, null),
  ('legacy_29_v1', 'teams',           true, null),
  ('legacy_29_v1', 'analytics',       true, null),
  ('legacy_29_v1', 'donations.page',  true, null),
  ('legacy_29_v1', 'video_messages',  true, null),
  ('legacy_29_v1', 'twilio.numbers',  null, null);

-- (Backfill is implicit: the plan_id column default stamped legacy_29_v1
-- on every existing tenant.)

-- 4. Resolvers. --------------------------------------------------------------
-- Limits: override (unexpired) wins, else plan value. NULL = unlimited.
-- No row at all = 0 (fail closed).
create or replace function public.tenant_limit(p_tenant uuid, p_key text)
returns numeric language plpgsql stable security definer set search_path to 'public' as $$
declare v numeric;
begin
  select o.limit_value into v
    from tenant_entitlement_overrides o
    where o.tenant_id = p_tenant and o.feature_key = p_key
      and (o.expires_at is null or o.expires_at > now());
  if found then return v; end if;
  select pe.limit_value into v
    from plan_entitlements pe
    join tenants t on t.id = p_tenant
      and pe.plan_id = coalesce(t.plan_id, 'legacy_29_v1')
    where pe.feature_key = p_key;
  if found then return v; end if;
  return 0;
end $$;

-- Flags: same precedence; missing row = false (fail closed).
create or replace function public.tenant_flag(p_tenant uuid, p_key text)
returns boolean language plpgsql stable security definer set search_path to 'public' as $$
declare v boolean;
begin
  select o.bool_value into v
    from tenant_entitlement_overrides o
    where o.tenant_id = p_tenant and o.feature_key = p_key
      and (o.expires_at is null or o.expires_at > now());
  if found then return coalesce(v, false); end if;
  select pe.bool_value into v
    from plan_entitlements pe
    join tenants t on t.id = p_tenant
      and pe.plan_id = coalesce(t.plan_id, 'legacy_29_v1')
    where pe.feature_key = p_key;
  if found then return coalesce(v, false); end if;
  return false;
end $$;

-- Everything the client needs in one call at Shell load: resolved
-- entitlements + current usage (for cap banners). Any signed-in member may
-- read their own tenant's entitlements.
create or replace function public.get_entitlements()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_tenant uuid := auth_tenant_id();
  v_plan text;
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  select coalesce(plan_id, 'legacy_29_v1') into v_plan from tenants where id = v_tenant;
  return jsonb_build_object(
    'plan', (select jsonb_build_object('id', p.id, 'name', p.name,
        'is_public', p.is_public, 'price_monthly_cents', p.price_monthly_cents)
      from plans p where p.id = v_plan),
    'features', (
      select jsonb_object_agg(f.key, jsonb_build_object(
        'kind', f.kind,
        'bool', tenant_flag(v_tenant, f.key),
        'limit', tenant_limit(v_tenant, f.key)))
      from features f),
    'usage', jsonb_build_object(
      'donors_active', (select count(*) from donors d
        where d.tenant_id = v_tenant and d.status = 'active'),
      'senders', (select count(*) from users u
        where u.tenant_id = v_tenant and u.role in ('admin', 'sender')))
  );
end $$;

revoke execute on function public.tenant_limit(uuid, text) from public, anon;
revoke execute on function public.tenant_flag(uuid, text) from public, anon;
revoke execute on function public.get_entitlements() from public, anon;

-- 5. Enforcement triggers (fail closed, revenue-bearing limits). -------------
-- Donor cap: blocks NEW active donors (insert, or restore back to active).
-- Existing data is never hidden or deleted (BILLING.md cap policy).
create or replace function public.enforce_donor_cap()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_limit numeric; v_count bigint;
begin
  -- Only transitions INTO active status consume cap.
  if new.status is distinct from 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  v_limit := tenant_limit(new.tenant_id, 'supporters.max');
  if v_limit is null then return new; end if; -- unlimited
  select count(*) into v_count from donors
    where tenant_id = new.tenant_id and status = 'active'
      and (tg_op = 'INSERT' or id <> new.id);
  if v_count >= v_limit then
    raise exception 'Supporter limit reached (% on your plan). Upgrade to add more.', v_limit::int
      using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger trg_donor_cap
  before insert or update of status on public.donors
  for each row execute function public.enforce_donor_cap();

-- Sender-seat cap: counts admin+sender users; viewers are always free.
-- Fires on users insert/role change/tenant move (invitation accept) and on
-- non-viewer invitation creation (pending invites hold a seat so an org
-- can't over-invite).
create or replace function public.enforce_seat_cap()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_limit numeric; v_count bigint; v_tenant uuid;
begin
  if tg_table_name = 'users' then
    if new.role not in ('admin', 'sender') then return new; end if;
    if tg_op = 'UPDATE' and old.tenant_id = new.tenant_id
       and old.role in ('admin', 'sender') then return new; end if;
    v_tenant := new.tenant_id;
  else -- invitations
    if new.role not in ('admin', 'sender') then return new; end if;
    v_tenant := new.tenant_id;
  end if;
  v_limit := tenant_limit(v_tenant, 'seats.senders');
  if v_limit is null then return new; end if; -- unlimited
  select (select count(*) from users u
            where u.tenant_id = v_tenant and u.role in ('admin', 'sender')
              and (tg_table_name <> 'users' or u.id <> new.id))
       + (select count(*) from invitations i
            where i.tenant_id = v_tenant and i.accepted_at is null
              and i.role in ('admin', 'sender')
              and (tg_table_name <> 'invitations' or i.id <> new.id))
    into v_count;
  if v_count >= v_limit then
    raise exception 'Sender seat limit reached (% on your plan). Upgrade to add more senders, or invite them as a viewer.', v_limit::int
      using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger trg_seat_cap_users
  before insert or update of role, tenant_id on public.users
  for each row execute function public.enforce_seat_cap();
create trigger trg_seat_cap_invitations
  before insert on public.invitations
  for each row execute function public.enforce_seat_cap();
