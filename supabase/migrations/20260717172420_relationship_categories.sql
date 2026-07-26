-- ============ Relationship categories ======================================
-- Who a contact is to the ministry: Donor, Volunteer, Coworker, Family, ...
-- Per-org customizable list (presets seeded) + many-to-many tags on donors.
-- Multiple categories per person; new orgs get the presets via trigger;
-- existing contacts were backfilled as "Donor" (the is_default type).

-- 1. The per-tenant category list. ------------------------------------------
create table public.relationship_types (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_preset boolean not null default false,  -- seeded, vs. org-created
  is_default boolean not null default false, -- pre-selected for new contacts
  created_at timestamptz not null default now(),
  unique (tenant_id, name)
);

-- 2. Tags: donor <-> category (a person can be Donor AND Volunteer). --------
create table public.donor_relationship_tags (
  donor_id uuid not null references public.donors(id) on delete cascade,
  type_id uuid not null references public.relationship_types(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (donor_id, type_id)
);

alter table public.relationship_types enable row level security;
alter table public.donor_relationship_tags enable row level security;

create policy tenant_isolation on public.relationship_types
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create policy tenant_isolation on public.donor_relationship_tags
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create index relationship_types_tenant_idx on public.relationship_types (tenant_id);
create index donor_relationship_tags_tenant_idx on public.donor_relationship_tags (tenant_id);
create index donor_relationship_tags_type_idx on public.donor_relationship_tags (type_id);

create trigger trg_relationship_types_tenant
  before insert on public.relationship_types
  for each row execute function set_tenant_id();
create trigger trg_donor_relationship_tags_tenant
  before insert on public.donor_relationship_tags
  for each row execute function set_tenant_id();

-- 3. Role/shadow/suspension enforcement — same restrictive-policy patterns
--    as every other tenant table (see tenant_security_levels + shadow +
--    suspension migrations). Managing the LIST is admin-only (like custom
--    field defs); TAGGING donors is open to senders (like donors writes);
--    viewers are read-only everywhere.
do $$
declare t text;
begin
  foreach t in array array['relationship_types','donor_relationship_tags'] loop
    execute format('create policy viewer_ro_ins on %I as restrictive for insert with check (coalesce(tenant_role(), '''') <> ''viewer'')', t);
    execute format('create policy viewer_ro_upd on %I as restrictive for update using (coalesce(tenant_role(), '''') <> ''viewer'')', t);
    execute format('create policy viewer_ro_del on %I as restrictive for delete using (coalesce(tenant_role(), '''') <> ''viewer'')', t);
    execute format('create policy shadow_ro_ins on %I as restrictive for insert with check (active_shadow_tenant() is null)', t);
    execute format('create policy shadow_ro_upd on %I as restrictive for update using (active_shadow_tenant() is null)', t);
    execute format('create policy shadow_ro_del on %I as restrictive for delete using (active_shadow_tenant() is null)', t);
    execute format('create policy suspended_ro_ins on %I as restrictive for insert with check (tenant_not_suspended())', t);
    execute format('create policy suspended_ro_upd on %I as restrictive for update using (tenant_not_suspended())', t);
    execute format('create policy suspended_ro_del on %I as restrictive for delete using (tenant_not_suspended())', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['relationship_types'] loop
    execute format('create policy admin_only_ins on %I as restrictive for insert with check (coalesce(tenant_role(), '''') = ''admin'')', t);
    execute format('create policy admin_only_upd on %I as restrictive for update using (coalesce(tenant_role(), '''') = ''admin'')', t);
    execute format('create policy admin_only_del on %I as restrictive for delete using (coalesce(tenant_role(), '''') = ''admin'')', t);
  end loop;
end $$;

-- 4. Presets for every EXISTING org. ----------------------------------------
insert into public.relationship_types (tenant_id, name, sort_order, is_preset, is_default)
select t.id, v.name, v.ord, true, v.name = 'Donor'
from public.tenants t
cross join (values ('Donor', 0), ('Volunteer', 1), ('Coworker', 2), ('Family', 3))
  as v(name, ord)
on conflict (tenant_id, name) do nothing;

-- 5. Presets for every FUTURE org (fires on tenant creation regardless of
--    path: email signup, OAuth, admin console). ------------------------------
create or replace function public.seed_relationship_presets()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.relationship_types (tenant_id, name, sort_order, is_preset, is_default)
  values (new.id, 'Donor', 0, true, true),
         (new.id, 'Volunteer', 1, true, false),
         (new.id, 'Coworker', 2, true, false),
         (new.id, 'Family', 3, true, false)
  on conflict (tenant_id, name) do nothing;
  return new;
end $$;
revoke execute on function public.seed_relationship_presets() from anon, authenticated, public;

create trigger trg_seed_relationship_presets
  after insert on public.tenants
  for each row execute function public.seed_relationship_presets();

-- 6. Backfill: every existing contact starts as "Donor" (per launch decision).
insert into public.donor_relationship_tags (donor_id, type_id, tenant_id)
select d.id, rt.id, d.tenant_id
from public.donors d
join public.relationship_types rt
  on rt.tenant_id = d.tenant_id and rt.is_default
on conflict do nothing;
