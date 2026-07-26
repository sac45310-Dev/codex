-- BUG caught by the new E2E suite (tests/e2e/run.mjs): BEFORE-INSERT
-- triggers fire in ALPHABETICAL order, and trg_donor_cap sorts before the
-- set_tenant_id trigger — so on client inserts (which never send tenant_id,
-- per the CLAUDE.md rule) the cap check ran with tenant_id NULL, resolved
-- the limit as 0 (fail closed), and blocked EVERY free-tier donor insert.
-- Earlier verification missed it because service-role tests set tenant_id
-- explicitly. Fix: resolve the tenant from the auth context when the
-- column hasn't been stamped yet.
create or replace function public.enforce_donor_cap()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_limit numeric; v_count bigint; v_tenant uuid;
begin
  -- Only transitions INTO active status consume cap.
  if new.status is distinct from 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  -- Client inserts rely on the set_tenant_id trigger, which may not have
  -- fired yet (alphabetical trigger order) — fall back to the auth context.
  v_tenant := coalesce(new.tenant_id, auth_tenant_id());
  if v_tenant is null then return new; end if; -- service-role bulk paths
  v_limit := tenant_limit(v_tenant, 'supporters.max');
  if v_limit is null then return new; end if; -- unlimited
  select count(*) into v_count from donors
    where tenant_id = v_tenant and status = 'active'
      and (tg_op = 'INSERT' or id <> new.id);
  if v_count >= v_limit then
    raise exception 'Supporter limit reached (% on your plan). Upgrade to add more.', v_limit::int
      using errcode = 'P0001';
  end if;
  return new;
end $$;
