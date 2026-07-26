-- Platform administration + consent-gated read-only shadow ("support access").
-- Staff roles: owner (everything + emergency override), support (shadow with
-- tenant consent), billing (console view only, no shadow).

-- ── Tables ────────────────────────────────────────────────────────────
create table platform_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','support','billing')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
alter table platform_staff enable row level security;

create table support_grants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  granted_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  revoked_at timestamptz
);
alter table support_grants enable row level security;
create index support_grants_active on support_grants (tenant_id) where revoked_at is null;

create table support_sessions (
  id uuid primary key default gen_random_uuid(),
  staff_user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  is_override boolean not null default false,
  reason text,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);
alter table support_sessions enable row level security;
create index support_sessions_active on support_sessions (staff_user_id) where ended_at is null;

-- ── Helpers ───────────────────────────────────────────────────────────
create or replace function platform_role() returns text
language sql stable security definer set search_path to 'public'
as $$ select role from platform_staff where user_id = auth.uid() $$;

create or replace function is_tenant_admin() returns boolean
language sql stable security definer set search_path to 'public'
as $$ select exists (select 1 from users where id = auth.uid() and role = 'admin') $$;

-- Active shadow session for the caller. Sessions self-expire after 4 hours
-- and die instantly if the tenant's grant is revoked (override sessions
-- carry their own authority).
create or replace function active_shadow_tenant() returns uuid
language sql stable security definer set search_path to 'public'
as $$
  select s.tenant_id from support_sessions s
  where s.staff_user_id = auth.uid()
    and s.ended_at is null
    and s.started_at > now() - interval '4 hours'
    and (
      s.is_override
      or exists (
        select 1 from support_grants g
        where g.tenant_id = s.tenant_id
          and g.revoked_at is null
          and g.expires_at > now()
      )
    )
  order by s.started_at desc
  limit 1
$$;

-- Shadow-aware tenant resolution: staff with an active session read as the
-- target tenant; everyone else exactly as before.
create or replace function auth_tenant_id() returns uuid
language sql stable security definer set search_path to 'public'
as $$
  select coalesce(
    case when exists (select 1 from platform_staff p where p.user_id = auth.uid())
         then active_shadow_tenant() end,
    (select tenant_id from public.users where id = auth.uid())
  )
$$;

-- ── Read-only enforcement during shadow ──────────────────────────────
-- Restrictive policies AND with the permissive tenant policies: while a
-- shadow session is active the staff user cannot write ANY tenant-scoped
-- row anywhere. Reads are untouched.
do $$
declare t text;
begin
  foreach t in array array[
    'activity_log','children','client_errors','consent_events',
    'custom_field_defs','custom_field_values','donations','donor_families',
    'donor_family_members','donor_notes','donors','event_actions',
    'invitations','key_dates','message_templates','messages',
    'prepared_messages','segment_members','segments','users'
  ] loop
    execute format('create policy shadow_ro_ins on %I as restrictive for insert with check (active_shadow_tenant() is null)', t);
    execute format('create policy shadow_ro_upd on %I as restrictive for update using (active_shadow_tenant() is null)', t);
    execute format('create policy shadow_ro_del on %I as restrictive for delete using (active_shadow_tenant() is null)', t);
  end loop;
end $$;

-- ── RLS for the new tables ────────────────────────────────────────────
create policy staff_select on platform_staff for select
  using (platform_role() is not null);
create policy staff_owner_insert on platform_staff for insert
  with check (platform_role() = 'owner');
create policy staff_owner_update on platform_staff for update
  using (platform_role() = 'owner');
create policy staff_owner_delete on platform_staff for delete
  using (platform_role() = 'owner' and user_id <> auth.uid());

-- Tenant admins manage/see their own grant; staff see all grants.
create policy grants_select on support_grants for select
  using (tenant_id = auth_tenant_id() or platform_role() is not null);
create policy grants_insert on support_grants for insert
  with check (tenant_id = auth_tenant_id() and is_tenant_admin()
              and active_shadow_tenant() is null);
create policy grants_update on support_grants for update
  using (tenant_id = auth_tenant_id() and is_tenant_admin()
         and active_shadow_tenant() is null);

-- Tenants can see every session into their org (transparency); staff see all.
create policy sessions_select on support_sessions for select
  using (tenant_id = auth_tenant_id() or platform_role() is not null);

-- ── RPCs ─────────────────────────────────────────────────────────────
create or replace function start_shadow(p_tenant_id uuid, p_reason text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_role text; v_granted boolean; v_id uuid;
begin
  select role into v_role from platform_staff where user_id = auth.uid();
  if v_role is null or v_role = 'billing' then
    raise exception 'Not authorized to shadow';
  end if;
  select exists (
    select 1 from support_grants g
    where g.tenant_id = p_tenant_id and g.revoked_at is null and g.expires_at > now()
  ) into v_granted;
  if not v_granted then
    if v_role <> 'owner' then
      raise exception 'This organization has not granted support access';
    end if;
    if p_reason is null or length(trim(p_reason)) < 10 then
      raise exception 'Emergency override requires a reason (10+ characters)';
    end if;
  end if;
  update support_sessions set ended_at = now()
    where staff_user_id = auth.uid() and ended_at is null;
  insert into support_sessions (staff_user_id, tenant_id, is_override, reason)
    values (auth.uid(), p_tenant_id, not v_granted, nullif(trim(coalesce(p_reason,'')), ''))
    returning id into v_id;
  return v_id;
end $$;

create or replace function end_shadow() returns void
language sql security definer set search_path to 'public' as $$
  update support_sessions set ended_at = now()
  where staff_user_id = auth.uid() and ended_at is null
$$;

-- One call the client makes on load: staff role + active shadow context.
create or replace function get_platform_context() returns json
language sql stable security definer set search_path to 'public' as $$
  select case when platform_role() is null then null else json_build_object(
    'role', platform_role(),
    'shadow', (
      select json_build_object(
        'tenant_id', t.id, 'legal_name', t.legal_name,
        'is_override', s.is_override, 'started_at', s.started_at,
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

create or replace function admin_list_tenants()
returns table (
  id uuid, legal_name text, created_at timestamptz, onboarded_at timestamptz,
  subscription_status text, plan text, billing_mode text,
  user_count bigint, donor_count bigint, grant_expires timestamptz
) language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  select t.id, t.legal_name, t.created_at, t.onboarded_at,
         t.subscription_status, t.plan, t.billing_mode,
         (select count(*) from users u where u.tenant_id = t.id),
         (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active'),
         (select max(g.expires_at) from support_grants g
           where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now())
  from tenants t order by t.created_at desc;
end $$;

create or replace function admin_list_staff()
returns table (user_id uuid, email text, name text, role text, created_at timestamptz)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  select p.user_id, coalesce(u.email, au.email::text), u.name, p.role, p.created_at
  from platform_staff p
  left join users u on u.id = p.user_id
  left join auth.users au on au.id = p.user_id
  order by p.created_at;
end $$;

create or replace function admin_add_staff(p_email text, p_role text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid;
begin
  if platform_role() <> 'owner' then raise exception 'Only the owner can add staff'; end if;
  if p_role not in ('owner','support','billing') then raise exception 'Bad role'; end if;
  select id into v_uid from auth.users where lower(email) = lower(trim(p_email));
  if v_uid is null then
    raise exception 'No account found for % — have them sign up first', p_email;
  end if;
  insert into platform_staff (user_id, role, created_by)
    values (v_uid, p_role, auth.uid())
    on conflict (user_id) do update set role = excluded.role;
end $$;

create or replace function admin_remove_staff(p_user_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if platform_role() <> 'owner' then raise exception 'Only the owner can remove staff'; end if;
  if p_user_id = auth.uid() then raise exception 'You cannot remove yourself'; end if;
  update support_sessions set ended_at = now()
    where staff_user_id = p_user_id and ended_at is null;
  delete from platform_staff where user_id = p_user_id;
end $$;

create or replace function admin_list_sessions(p_limit int default 50)
returns table (
  id uuid, staff_email text, tenant_name text, is_override boolean,
  reason text, started_at timestamptz, ended_at timestamptz
) language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  select s.id, au.email::text, t.legal_name, s.is_override, s.reason,
         s.started_at, s.ended_at
  from support_sessions s
  join auth.users au on au.id = s.staff_user_id
  join tenants t on t.id = s.tenant_id
  order by s.started_at desc limit p_limit;
end $$;

-- Tenant-side consent controls (called from their Settings).
create or replace function grant_support_access(p_days int default 7)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not is_tenant_admin() then raise exception 'Only an admin can grant support access'; end if;
  if active_shadow_tenant() is not null then raise exception 'Not available during a support session'; end if;
  if p_days < 1 or p_days > 30 then raise exception 'Grant must be 1-30 days'; end if;
  update support_grants set revoked_at = now()
    where tenant_id = auth_tenant_id() and revoked_at is null;
  insert into support_grants (tenant_id, granted_by, expires_at)
    values (auth_tenant_id(), auth.uid(), now() + make_interval(days => p_days));
end $$;

create or replace function revoke_support_access()
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not is_tenant_admin() then raise exception 'Only an admin can revoke support access'; end if;
  update support_grants set revoked_at = now()
    where tenant_id = auth_tenant_id() and revoked_at is null;
  -- Revoking consent boots any live consent-based session immediately.
  update support_sessions set ended_at = now()
    where tenant_id = auth_tenant_id() and ended_at is null and not is_override;
end $$;

-- ── Seed ─────────────────────────────────────────────────────────────
insert into platform_staff (user_id, role, created_by)
values ('3fe41174-9e07-4e00-9bae-7609941cc46a', 'owner',
        '3fe41174-9e07-4e00-9bae-7609941cc46a');
