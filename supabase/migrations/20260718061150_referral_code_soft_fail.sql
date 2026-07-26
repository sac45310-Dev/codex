-- Bad-code attempts must return a soft failure, not raise: a raise rolls
-- back the code_attempt_failed audit insert in the same function, so the
-- rate limiter never accumulated (caught in Phase A verification). The
-- invalid-code path now logs the attempt AND reports the error via
-- {ok:false, error} — clients check data.ok. Hard raises remain for the
-- states that need no attempt logging (already applied, not net-new, off).
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
  -- One opaque soft failure for bad code AND self-referral (no enumeration),
  -- returned rather than raised so the attempt log above survives.
  if v_referrer.id is null or v_referrer.id = v_tenant then
    insert into referral_events (tenant_id, event_type, detail)
      values (v_tenant, 'code_attempt_failed', jsonb_build_object('code', v_code));
    return jsonb_build_object('ok', false, 'error', 'That code isn''t valid.');
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
