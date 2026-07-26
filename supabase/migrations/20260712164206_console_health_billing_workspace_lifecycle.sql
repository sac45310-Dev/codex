-- Console upgrade #2/#1/#4/#3: org health, billing controls + platform audit,
-- support workspace (notes, act-as, MFA-gated staff), org lifecycle.

-- ── Platform audit trail (billing/lifecycle/management actions) ───────
-- tenant_id has NO FK on purpose: events must survive org deletion.
create table platform_events (
  id uuid primary key default gen_random_uuid(),
  staff_user_id uuid references auth.users(id) on delete set null,
  tenant_id uuid,
  tenant_name text,
  action text not null,
  detail text,
  created_at timestamptz not null default now()
);
alter table platform_events enable row level security;
create policy events_staff_sel on platform_events for select
  using (platform_role() is not null);

create or replace function log_platform_event(p_tenant uuid, p_action text, p_detail text)
returns void language sql security definer set search_path to 'public' as $$
  insert into platform_events (staff_user_id, tenant_id, tenant_name, action, detail)
  values (auth.uid(), p_tenant,
          (select legal_name from tenants where id = p_tenant), p_action, p_detail)
$$;

-- ── #4 Support notes ──────────────────────────────────────────────────
create table platform_notes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  author_email text,
  body text not null,
  created_at timestamptz not null default now()
);
alter table platform_notes enable row level security;
create policy notes_staff_sel on platform_notes for select using (platform_role() is not null);
create policy notes_staff_ins on platform_notes for insert
  with check (platform_role() in ('owner','support','billing') and author_id = auth.uid());
create policy notes_del on platform_notes for delete
  using (platform_role() = 'owner' or author_id = auth.uid());

-- ── #4 Act-as mode ────────────────────────────────────────────────────
alter table support_sessions add column mode text not null default 'shadow'
  check (mode in ('shadow','act'));

-- Writes are blocked only for read-only ('shadow') sessions; 'act' sessions
-- write as normal (attributed via the session audit + created_by columns).
create or replace function shadow_write_blocked() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from support_sessions s
    where s.staff_user_id = auth.uid() and s.ended_at is null
      and s.started_at > now() - interval '4 hours'
      and s.mode = 'shadow'
      and s.tenant_id = active_shadow_tenant()
  )
$$;

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
    execute format('drop policy shadow_ro_ins on %I', t);
    execute format('drop policy shadow_ro_upd on %I', t);
    execute format('drop policy shadow_ro_del on %I', t);
    execute format('create policy shadow_ro_ins on %I as restrictive for insert with check (not shadow_write_blocked())', t);
    execute format('create policy shadow_ro_upd on %I as restrictive for update using (not shadow_write_blocked())', t);
    execute format('create policy shadow_ro_del on %I as restrictive for delete using (not shadow_write_blocked())', t);
  end loop;
end $$;

drop function if exists start_shadow(uuid, text);
create or replace function start_shadow(p_tenant_id uuid, p_reason text default null, p_mode text default 'shadow')
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_role text; v_granted boolean; v_id uuid;
begin
  select platform_role() into v_role;
  if v_role is null or v_role = 'billing' then
    raise exception 'Not authorized to shadow';
  end if;
  if p_mode not in ('shadow','act') then raise exception 'Bad mode'; end if;
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
  insert into support_sessions (staff_user_id, tenant_id, is_override, reason, mode)
    values (auth.uid(), p_tenant_id, not v_granted, nullif(trim(coalesce(p_reason,'')), ''), p_mode)
    returning id into v_id;
  return v_id;
end $$;

-- ── #4 Staff MFA enforcement ─────────────────────────────────────────
-- Once a staff member has a verified TOTP factor, their staff powers only
-- exist at aal2 — a stolen password alone gets nothing.
create or replace function platform_role() returns text
language sql stable security definer set search_path to 'public'
as $$
  select p.role from platform_staff p
  where p.user_id = auth.uid()
    and (
      not exists (select 1 from auth.mfa_factors f
                  where f.user_id = auth.uid() and f.status = 'verified')
      or coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
    )
$$;

-- ── #3 Suspension ─────────────────────────────────────────────────────
alter table tenants add column suspended_at timestamptz;

create or replace function admin_suspend_tenant(p_tenant_id uuid, p_reason text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'Reason required'; end if;
  update tenants set suspended_at = now() where id = p_tenant_id and suspended_at is null;
  update support_sessions set ended_at = now() where tenant_id = p_tenant_id and ended_at is null;
  perform log_platform_event(p_tenant_id, 'suspend', p_reason);
end $$;

create or replace function admin_unsuspend_tenant(p_tenant_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  update tenants set suspended_at = null where id = p_tenant_id;
  perform log_platform_event(p_tenant_id, 'unsuspend', null);
end $$;

-- ── #3 Export + delete ────────────────────────────────────────────────
create or replace function admin_export_tenant(p_tenant_id uuid)
returns json language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  perform log_platform_event(p_tenant_id, 'export', null);
  return json_build_object(
    'exported_at', now(),
    'tenant', (select to_json(t) from tenants t where t.id = p_tenant_id),
    'users', (select coalesce(json_agg(json_build_object('name', u.name, 'email', u.email, 'role', u.role)), '[]'::json) from users u where u.tenant_id = p_tenant_id),
    'donors', (select coalesce(json_agg(to_json(d)), '[]'::json) from donors d where d.tenant_id = p_tenant_id),
    'donations', (select coalesce(json_agg(to_json(g)), '[]'::json) from donations g where g.tenant_id = p_tenant_id),
    'donor_notes', (select coalesce(json_agg(to_json(n)), '[]'::json) from donor_notes n where n.tenant_id = p_tenant_id),
    'key_dates', (select coalesce(json_agg(to_json(k)), '[]'::json) from key_dates k where k.tenant_id = p_tenant_id),
    'segments', (select coalesce(json_agg(to_json(s)), '[]'::json) from segments s where s.tenant_id = p_tenant_id)
  );
end $$;

create or replace function admin_delete_tenant(p_tenant_id uuid, p_confirm_name text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_name text; v_suspended timestamptz;
begin
  if platform_role() <> 'owner' then raise exception 'Only the owner can delete an organization'; end if;
  select legal_name, suspended_at into v_name, v_suspended from tenants where id = p_tenant_id;
  if v_name is null then raise exception 'Not found'; end if;
  if v_suspended is null then raise exception 'Suspend the organization first — deletion requires it'; end if;
  if trim(p_confirm_name) <> v_name then raise exception 'Name confirmation does not match'; end if;
  perform log_platform_event(p_tenant_id, 'delete_org', v_name);
  delete from users where tenant_id = p_tenant_id; -- profile rows (auth accounts survive)
  delete from tenants where id = p_tenant_id;      -- cascades all org data
end $$;

-- ── #1 Billing controls ───────────────────────────────────────────────
create or replace function admin_set_billing(p_tenant_id uuid, p_action text, p_days int default 14)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if platform_role() not in ('owner','support','billing') then
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

-- ── Management RPCs now log events ────────────────────────────────────
create or replace function admin_rename_tenant(p_tenant_id uuid, p_name text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Name required'; end if;
  update tenants set legal_name = trim(p_name) where id = p_tenant_id;
  perform log_platform_event(p_tenant_id, 'rename', trim(p_name));
end $$;

create or replace function admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_tid uuid; v_admins int; v_email text;
begin
  perform assert_staff_manager();
  if p_role not in ('admin','sender','viewer') then raise exception 'Bad role'; end if;
  select tenant_id, email into v_tid, v_email from users where id = p_user_id;
  if v_tid is null then raise exception 'User not found'; end if;
  if p_role <> 'admin' then
    select count(*) into v_admins from users
      where tenant_id = v_tid and role = 'admin' and id <> p_user_id;
    if v_admins = 0 then
      raise exception 'This is the only admin — promote someone else first';
    end if;
  end if;
  update users set role = p_role::user_role where id = p_user_id;
  perform log_platform_event(v_tid, 'set_role', v_email || ' → ' || p_role);
end $$;

-- ── #2 Health data in list/detail + #1 MRR in stats ──────────────────
drop function if exists admin_list_tenants();
create function admin_list_tenants()
returns table (
  id uuid, legal_name text, created_at timestamptz, onboarded_at timestamptz,
  subscription_status text, plan text, billing_mode text, suspended_at timestamptz,
  current_period_end timestamptz, user_count bigint, donor_count bigint,
  grant_expires timestamptz, last_activity timestamptz, errors_7d bigint
) language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return query
  select t.id, t.legal_name, t.created_at, t.onboarded_at,
         t.subscription_status, t.plan, t.billing_mode, t.suspended_at,
         t.current_period_end,
         (select count(*) from users u where u.tenant_id = t.id),
         (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active'),
         (select max(g.expires_at) from support_grants g
           where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now()),
         (select max(a.created_at) from activity_log a where a.tenant_id = t.id),
         (select count(*) from client_errors e
           where e.tenant_id = t.id and e.created_at > now() - interval '7 days')
  from tenants t order by t.created_at desc;
end $$;

drop function if exists admin_stats();
create function admin_stats() returns json
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return json_build_object(
    'orgs', (select count(*) from tenants),
    'active_subs', (select count(*) from tenants where subscription_status = 'active'),
    'trialing', (select count(*) from tenants where subscription_status = 'trialing'),
    'donors', (select count(*) from donors where status = 'active'),
    'orgs_30d', (select count(*) from tenants where created_at > now() - interval '30 days'),
    'open_sessions', (select count(*) from support_sessions where ended_at is null),
    'mrr', (select coalesce(sum(case
        when subscription_status <> 'active' then 0
        when plan = 'monthly' then 29
        when plan = 'annual' then 24
        else 0 end), 0) from tenants),
    'errors_7d', (select count(*) from client_errors where created_at > now() - interval '7 days')
  );
end $$;

drop function if exists admin_tenant_detail(uuid);
create function admin_tenant_detail(p_tenant_id uuid)
returns json language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return (
    select json_build_object(
      'id', t.id, 'legal_name', t.legal_name, 'created_at', t.created_at,
      'onboarded_at', t.onboarded_at, 'subscription_status', t.subscription_status,
      'plan', t.plan, 'billing_mode', t.billing_mode, 'suspended_at', t.suspended_at,
      'current_period_end', t.current_period_end,
      'stripe_customer_id', t.stripe_customer_id,
      'city', t.city, 'state', t.state, 'ein', t.ein,
      'donor_count', (select count(*) from donors d where d.tenant_id = t.id and d.status = 'active'),
      'grant_expires', (select max(g.expires_at) from support_grants g
        where g.tenant_id = t.id and g.revoked_at is null and g.expires_at > now()),
      'last_activity', (select max(a.created_at) from activity_log a where a.tenant_id = t.id),
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
          'is_override', s.is_override, 'mode', s.mode, 'reason', s.reason) order by s.started_at desc)
        from (select * from support_sessions ss where ss.tenant_id = t.id
              order by ss.started_at desc limit 10) s), '[]'::json),
      'activity', coalesce((select json_agg(json_build_object(
          'action', a.action, 'detail', a.detail, 'created_at', a.created_at) order by a.created_at desc)
        from (select * from activity_log al where al.tenant_id = t.id
              order by al.created_at desc limit 10) a), '[]'::json),
      'errors', coalesce((select json_agg(json_build_object(
          'message', e.message, 'url', e.url, 'created_at', e.created_at) order by e.created_at desc)
        from (select * from client_errors ce where ce.tenant_id = t.id
              order by ce.created_at desc limit 10) e), '[]'::json),
      'notes', coalesce((select json_agg(json_build_object(
          'id', n.id, 'body', n.body, 'author_email', n.author_email,
          'author_id', n.author_id, 'created_at', n.created_at) order by n.created_at desc)
        from platform_notes n where n.tenant_id = t.id), '[]'::json),
      'events', coalesce((select json_agg(json_build_object(
          'action', ev.action, 'detail', ev.detail, 'created_at', ev.created_at) order by ev.created_at desc)
        from (select * from platform_events pe where pe.tenant_id = t.id
              order by pe.created_at desc limit 10) ev), '[]'::json)
    )
    from tenants t where t.id = p_tenant_id
  );
end $$;

create or replace function admin_add_note(p_tenant_id uuid, p_body text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  if length(trim(coalesce(p_body,''))) < 1 then raise exception 'Empty note'; end if;
  insert into platform_notes (tenant_id, author_id, author_email, body)
    values (p_tenant_id, auth.uid(),
            (select email from auth.users where id = auth.uid()), trim(p_body));
end $$;
