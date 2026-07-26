-- Kids in a household: not donors, just family context + birthday reminders.
create table public.children (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  family_id uuid not null references public.donor_families(id) on delete cascade,
  first_name text not null,
  last_name text,
  birthday date,
  notes text,
  created_at timestamptz not null default now()
);
alter table public.children enable row level security;
create policy tenant_isolation on public.children
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create index children_tenant_idx on public.children (tenant_id);
create index children_family_idx on public.children (family_id);
create trigger trg_children_tenant
  before insert on public.children
  for each row execute function set_tenant_id();

-- One decision per event occurrence: texted, saved for later, or skipped.
create table public.event_actions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  kind text not null check (kind in ('key_date', 'child_birthday')),
  ref_id uuid not null,
  occurrence_date date not null,
  action text not null check (action in ('texted', 'saved', 'skipped')),
  acted_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (kind, ref_id, occurrence_date)
);
alter table public.event_actions enable row level security;
create policy tenant_isolation on public.event_actions
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create index event_actions_tenant_idx on public.event_actions (tenant_id);
create index event_actions_acted_by_idx on public.event_actions (acted_by);
create trigger trg_event_actions_tenant
  before insert on public.event_actions
  for each row execute function set_tenant_id();
