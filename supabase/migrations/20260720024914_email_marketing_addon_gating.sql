select set_config('app.allow_plan_edit','on',true);

insert into public.features (key, kind, description) values
  ('email.marketing','flag','Bulk email marketing (campaigns, opens, unsubscribes)'),
  ('email.monthly','limit','Marketing emails per month')
on conflict (key) do nothing;

insert into public.plan_entitlements (plan_id, feature_key, bool_value, limit_value) values
  ('launch_v1','email.marketing', true, null),
  ('launch_v1','email.monthly', null, '5000')
on conflict (plan_id, feature_key) do update
  set bool_value=excluded.bool_value, limit_value=excluded.limit_value;

insert into public.addons (id, name, price_monthly_cents, is_active) values
  ('email_marketing','Email marketing (5,000/mo)', 1000, true)
on conflict (id) do update set name=excluded.name, price_monthly_cents=excluded.price_monthly_cents;

create or replace function public.get_entitlements()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare v_tenant uuid := auth_tenant_id(); v_plan text;
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  select coalesce(plan_id, 'legacy_29_v1') into v_plan from tenants where id = v_tenant;
  return jsonb_build_object(
    'plan', (select jsonb_build_object('id', p.id, 'name', p.name,
        'is_public', p.is_public, 'price_monthly_cents', p.price_monthly_cents)
      from plans p where p.id = v_plan),
    'features', (select jsonb_object_agg(f.key, jsonb_build_object(
        'kind', f.kind, 'bool', tenant_flag(v_tenant, f.key), 'limit', tenant_limit(v_tenant, f.key)))
      from features f),
    'usage', jsonb_build_object(
      'donors_active', (select count(*) from donors d where d.tenant_id=v_tenant and d.status='active'),
      'senders', (select count(*) from users u where u.tenant_id=v_tenant and u.role in ('admin','sender')),
      'emails_sent_month', (select count(*) from scheduled_messages s
        where s.tenant_id=v_tenant and s.channel='email' and s.status='sent'
          and s.sent_at >= date_trunc('month', now())))
  );
end $function$;

create or replace function public.set_email_marketing(p_on boolean)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_tenant uuid := auth_tenant_id();
begin
  if v_tenant is null or coalesce(tenant_role(), '') <> 'admin' then
    raise exception 'Only admins can change the email add-on';
  end if;
  if p_on then
    insert into tenant_entitlement_overrides (tenant_id, feature_key, bool_value, reason, created_by)
      values (v_tenant, 'email.marketing', true, 'email add-on enabled', auth.uid())
      on conflict (tenant_id, feature_key) do update set bool_value=true, reason='email add-on enabled';
    insert into tenant_entitlement_overrides (tenant_id, feature_key, limit_value, reason, created_by)
      values (v_tenant, 'email.monthly', '5000', 'email add-on enabled', auth.uid())
      on conflict (tenant_id, feature_key) do update set limit_value='5000';
  else
    delete from tenant_entitlement_overrides
      where tenant_id=v_tenant and feature_key in ('email.marketing','email.monthly');
  end if;
end $$;
