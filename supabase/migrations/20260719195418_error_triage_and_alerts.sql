-- Error tracking v2, phase 2 (ERRORS.md): grouped triage RPCs for the
-- console + per-staff alert preferences (email on by default, SMS opt-in)
-- + a 15-minute cron that drives the error-alerts edge function.

-- ============ Alert preferences ============================================
alter table public.platform_staff
  add column alert_email_enabled boolean not null default true,
  add column alert_sms_enabled boolean not null default false,
  add column alert_sms_e164 text;

-- Staff manage their own alert prefs (guarded RPC, same posture as the
-- other admin_* functions — platform_staff has no client policies).
create or replace function public.admin_get_alert_prefs()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return (
    select jsonb_build_object(
      'alert_email_enabled', s.alert_email_enabled,
      'alert_sms_enabled', s.alert_sms_enabled,
      'alert_sms_e164', s.alert_sms_e164)
    from platform_staff s where s.user_id = auth.uid());
end $$;

create or replace function public.admin_set_alert_prefs(
  p_email_enabled boolean, p_sms_enabled boolean, p_sms_e164 text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  if p_sms_enabled and (p_sms_e164 is null or p_sms_e164 !~ '^\+[1-9]\d{6,14}$') then
    raise exception 'A valid phone number is required for text alerts';
  end if;
  update platform_staff set
    alert_email_enabled = p_email_enabled,
    alert_sms_enabled = p_sms_enabled,
    alert_sms_e164 = nullif(p_sms_e164, '')
  where user_id = auth.uid();
end $$;

-- ============ Grouped triage ===============================================
-- One row per distinct bug: counts, 7-day daily trend, affected orgs.
create or replace function public.admin_error_groups(p_status text default null)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(row order by (row->>'last_seen') desc) from (
      select jsonb_build_object(
        'fingerprint', g.fingerprint,
        'message', g.message_sample,
        'source', g.source,
        'severity', g.severity,
        'status', g.status,
        'first_seen', g.first_seen,
        'last_seen', g.last_seen,
        'event_count', g.event_count,
        'regressed_at', g.regressed_at,
        'resolved_release', g.resolved_release,
        'tenants_7d', (
          select count(distinct ce.tenant_id) from client_errors ce
          where ce.fingerprint = g.fingerprint
            and ce.created_at > now() - interval '7 days'),
        'trend', (
          select jsonb_agg(coalesce(day.n, 0) order by day.d) from (
            select d.d, count(ce.id) as n
            from generate_series(current_date - 6, current_date, '1 day') d(d)
            left join client_errors ce
              on ce.fingerprint = g.fingerprint and ce.created_at::date = d.d
            group by d.d) day)
      ) as row
      from error_groups g
      where p_status is null or g.status = p_status
      order by g.last_seen desc
      limit 100
    ) sub
  ), '[]'::jsonb);
end $$;

create or replace function public.admin_error_group_events(
  p_fingerprint text, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(e order by (e->>'created_at') desc) from (
      select jsonb_build_object(
        'id', ce.id,
        'message', ce.message,
        'stack', ce.stack,
        'url', ce.url,
        'user_agent', ce.user_agent,
        'org', t.legal_name,
        'source', ce.source,
        'severity', ce.severity,
        'release', ce.release,
        'context', ce.context,
        'created_at', ce.created_at
      ) as e
      from client_errors ce
      left join tenants t on t.id = ce.tenant_id
      where ce.fingerprint = p_fingerprint
      order by ce.created_at desc
      limit least(p_limit, 100)
    ) sub
  ), '[]'::jsonb);
end $$;

-- Resolve / ignore / reopen. Resolving pins the release the fix shipped in
-- (latest release seen), so the SAME release erroring again stays resolved
-- (stale tabs) while a NEWER release erroring reopens as a regression.
create or replace function public.admin_error_group_set_status(
  p_fingerprint text, p_status text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support') then
    raise exception 'Not authorized';
  end if;
  if p_status not in ('open', 'resolved', 'ignored') then
    raise exception 'Bad status';
  end if;
  update error_groups set
    status = p_status,
    status_changed_by = auth.uid(),
    resolved_at = case when p_status = 'resolved' then now() else null end,
    resolved_release = case when p_status = 'resolved' then (
      select ce.release from client_errors ce
      where ce.fingerprint = p_fingerprint and ce.release is not null
      order by ce.created_at desc limit 1) else null end,
    regressed_at = case when p_status = 'open' then regressed_at else null end
  where fingerprint = p_fingerprint;
  if not found then raise exception 'Unknown error group'; end if;
end $$;

-- ============ Alert cron ===================================================
-- Every 15 minutes; the edge function decides what (if anything) to send
-- and batches everything into one email / one text per staff member.
select cron.schedule(
  'error-alerts',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/error-alerts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')
    ),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
