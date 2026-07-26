-- Tenant security levels, enforced in the database:
--   admin  — everything, incl. org settings, team, custom fields, billing
--   sender — day-to-day work (donors, gifts, messages, segments, templates);
--            cannot touch org settings, team, or custom field definitions
--   viewer — read-only everywhere
-- Plus platform-console RPCs: create nonprofits, invite users, change roles.

create or replace function tenant_role() returns text
language sql stable security definer set search_path to 'public'
as $$ select role::text from users where id = auth.uid() $$;

-- Viewers write nothing, anywhere.
do $$
declare t text;
begin
  foreach t in array array[
    'activity_log','children','client_errors','consent_events',
    'custom_field_defs','custom_field_values','donations','donor_families',
    'donor_family_members','donor_notes','donors','event_actions',
    'invitations','key_dates','message_templates','messages',
    'prepared_messages','segment_members','segments'
  ] loop
    execute format('create policy viewer_ro_ins on %I as restrictive for insert with check (coalesce(tenant_role(), '''') <> ''viewer'')', t);
    execute format('create policy viewer_ro_upd on %I as restrictive for update using (coalesce(tenant_role(), '''') <> ''viewer'')', t);
    execute format('create policy viewer_ro_del on %I as restrictive for delete using (coalesce(tenant_role(), '''') <> ''viewer'')', t);
  end loop;
end $$;

-- Admin-only surfaces: org settings, team invitations, custom field defs.
create policy admin_only_upd on tenants as restrictive for update
  using (coalesce(tenant_role(), '') = 'admin');
do $$
declare t text;
begin
  foreach t in array array['invitations','custom_field_defs'] loop
    execute format('create policy admin_only_ins on %I as restrictive for insert with check (coalesce(tenant_role(), '''') = ''admin'')', t);
    execute format('create policy admin_only_upd on %I as restrictive for update using (coalesce(tenant_role(), '''') = ''admin'')', t);
    execute format('create policy admin_only_del on %I as restrictive for delete using (coalesce(tenant_role(), '''') = ''admin'')', t);
  end loop;
end $$;

-- ── Console RPCs (staff) ─────────────────────────────────────────────
create or replace function assert_staff_manager() returns void
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() not in ('owner','support') then
    raise exception 'Not authorized';
  end if;
end $$;

create or replace function admin_stats() returns json
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if platform_role() is null then raise exception 'Not authorized'; end if;
  return json_build_object(
    'orgs', (select count(*) from tenants),
    'active_subs', (select count(*) from tenants where subscription_status = 'active'),
    'trialing', (select count(*) from tenants where subscription_status = 'trialing'),
    'donors', (select count(*) from donors where status = 'active'),
    'orgs_30d', (select count(*) from tenants where created_at > now() - interval '30 days'),
    'open_sessions', (select count(*) from support_sessions where ended_at is null)
  );
end $$;

create or replace function admin_create_tenant(p_name text, p_admin_email text default null)
returns json language plpgsql security definer set search_path to 'public' as $$
declare v_tid uuid; v_token uuid;
begin
  perform assert_staff_manager();
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Organization name required'; end if;
  insert into tenants (legal_name, onboarded_at) values (trim(p_name), now())
    returning id into v_tid;
  if p_admin_email is not null and trim(p_admin_email) <> '' then
    insert into invitations (tenant_id, email, role, invited_by)
      values (v_tid, lower(trim(p_admin_email)), 'admin', auth.uid())
      returning token into v_token;
  end if;
  return json_build_object('tenant_id', v_tid, 'invite_token', v_token);
end $$;

create or replace function admin_invite_user(p_tenant_id uuid, p_email text, p_role text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_token uuid;
begin
  perform assert_staff_manager();
  if p_role not in ('admin','sender','viewer') then raise exception 'Bad role'; end if;
  insert into invitations (tenant_id, email, role, invited_by)
    values (p_tenant_id, lower(trim(p_email)), p_role::user_role, auth.uid())
    returning token into v_token;
  return v_token;
end $$;

create or replace function admin_revoke_invitation(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  delete from invitations where id = p_id and accepted_at is null;
end $$;

create or replace function admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_tid uuid; v_admins int;
begin
  perform assert_staff_manager();
  if p_role not in ('admin','sender','viewer') then raise exception 'Bad role'; end if;
  select tenant_id into v_tid from users where id = p_user_id;
  if v_tid is null then raise exception 'User not found'; end if;
  -- Never demote the last admin: the org would lock itself out.
  if p_role <> 'admin' then
    select count(*) into v_admins from users
      where tenant_id = v_tid and role = 'admin' and id <> p_user_id;
    if v_admins = 0 then
      raise exception 'This is the only admin — promote someone else first';
    end if;
  end if;
  update users set role = p_role::user_role where id = p_user_id;
end $$;

create or replace function admin_rename_tenant(p_tenant_id uuid, p_name text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform assert_staff_manager();
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Name required'; end if;
  update tenants set legal_name = trim(p_name) where id = p_tenant_id;
end $$;

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
