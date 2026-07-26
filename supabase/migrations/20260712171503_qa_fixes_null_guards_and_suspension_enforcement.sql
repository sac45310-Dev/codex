-- QA fixes from code review:
-- (1) CRITICAL: NULL-unsafe role guards. platform_role() is NULL for
--     non-staff; `NULL not in (...)` and `NULL <> 'owner'` evaluate to NULL,
--     so the raise never fired and any authenticated user could call the
--     billing/lifecycle/staff RPCs. coalesce() everywhere.
-- (2) Suspension enforced in the DB: suspended orgs lose ALL writes via
--     restrictive policies (reads stay so exports/support still work).

create or replace function assert_staff_manager() returns void
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner','support') then
    raise exception 'Not authorized';
  end if;
end $$;

create or replace function admin_set_billing(p_tenant_id uuid, p_action text, p_days int default 14)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner','support','billing') then
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

create or replace function admin_delete_tenant(p_tenant_id uuid, p_confirm_name text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_name text; v_suspended timestamptz; v_expected text;
begin
  if coalesce(platform_role(), '') <> 'owner' then
    raise exception 'Only the owner can delete an organization';
  end if;
  select legal_name, suspended_at into v_name, v_suspended from tenants where id = p_tenant_id;
  if not found then raise exception 'Not found'; end if;
  if v_suspended is null then raise exception 'Suspend the organization first — deletion requires it'; end if;
  -- Unnamed orgs (stuck signups) confirm with the literal word DELETE.
  v_expected := coalesce(nullif(trim(coalesce(v_name, '')), ''), 'DELETE');
  if trim(p_confirm_name) <> v_expected then
    raise exception 'Name confirmation does not match';
  end if;
  perform log_platform_event(p_tenant_id, 'delete_org', v_expected);
  delete from users where tenant_id = p_tenant_id;
  delete from tenants where id = p_tenant_id;
end $$;

create or replace function admin_add_staff(p_email text, p_role text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid;
begin
  if coalesce(platform_role(), '') <> 'owner' then raise exception 'Only the owner can add staff'; end if;
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
  if coalesce(platform_role(), '') <> 'owner' then raise exception 'Only the owner can remove staff'; end if;
  if p_user_id = auth.uid() then raise exception 'You cannot remove yourself'; end if;
  update support_sessions set ended_at = now()
    where staff_user_id = p_user_id and ended_at is null;
  delete from platform_staff where user_id = p_user_id;
end $$;

-- (2) Suspension: block every tenant-table write while the resolved tenant
-- is suspended. Reads survive (support investigation, data export, and the
-- lock screen's own profile load all need them).
create or replace function tenant_not_suspended() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select not exists (
    select 1 from tenants t
    where t.id = auth_tenant_id() and t.suspended_at is not null
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
    execute format('create policy suspended_ro_ins on %I as restrictive for insert with check (tenant_not_suspended())', t);
    execute format('create policy suspended_ro_upd on %I as restrictive for update using (tenant_not_suspended())', t);
    execute format('create policy suspended_ro_del on %I as restrictive for delete using (tenant_not_suspended())', t);
  end loop;
end $$;
