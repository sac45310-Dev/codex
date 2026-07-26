-- ============ Plan-edit guard (versioning protection) =======================
-- Editing a plan IN PLACE while organizations are subscribed to it changes
-- their entitlements live — almost always the wrong move (BILLING.md: create
-- a new version instead; old versions stay frozen forever). This guard makes
-- the in-place path deliberately manual: it raises unless the session sets
--   select set_config('app.allow_plan_edit', 'on', true);
-- first (the Phase 3 console RPC does this behind an explicit "affects all N
-- live organizations" confirm; ad-hoc SQL must opt in the same way).
--
-- Retirement/marketing fields (is_public, is_active_for_new, sort, blurb,
-- name) stay freely editable — retiring a version from new sales IS the
-- versioning workflow and must not be blocked.

create or replace function public.guard_plan_edit()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_plan text; v_live bigint;
begin
  if coalesce(current_setting('app.allow_plan_edit', true), '') = 'on' then
    return coalesce(new, old);
  end if;

  if tg_table_name = 'plans' then
    v_plan := old.id;
    if tg_op = 'UPDATE'
       and new.price_monthly_cents = old.price_monthly_cents
       and new.price_annual_cents  = old.price_annual_cents
       and new.trial_days          = old.trial_days
       and new.stripe_price_monthly is not distinct from old.stripe_price_monthly
       and new.stripe_price_annual  is not distinct from old.stripe_price_annual
       and new.id = old.id then
      return new; -- only safe fields changed
    end if;
  else -- plan_entitlements
    v_plan := coalesce(new.plan_id, old.plan_id);
  end if;

  select count(*) into v_live from tenants where plan_id = v_plan;
  if v_live > 0 then
    raise exception
      'Plan "%" has % live organization(s). Create a new plan version instead of editing in place — or, to intentionally change it for ALL of them, run select set_config(''app.allow_plan_edit'',''on'',true); first.',
      v_plan, v_live using errcode = 'P0001';
  end if;
  return coalesce(new, old);
end $$;

create trigger trg_guard_plans
  before update or delete on public.plans
  for each row execute function public.guard_plan_edit();
create trigger trg_guard_plan_entitlements
  before insert or update or delete on public.plan_entitlements
  for each row execute function public.guard_plan_edit();
