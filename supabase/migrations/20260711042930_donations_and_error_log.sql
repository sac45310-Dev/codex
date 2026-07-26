-- ============ Donations ====================================================
create table public.donations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  donor_id uuid not null references public.donors(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  currency char(3) not null default 'USD',
  date date not null default current_date,
  method text check (method in ('cash','check','card','ach','online','other')),
  fund text,
  note text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.donations enable row level security;
create policy tenant_isolation on public.donations
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create index donations_tenant_idx on public.donations (tenant_id);
create index donations_donor_date_idx on public.donations (donor_id, date desc);
create index donations_created_by_idx on public.donations (created_by);

create trigger trg_donations_tenant
  before insert on public.donations
  for each row execute function set_tenant_id();

-- Tenant-wide giving stats for the dashboard (SECURITY INVOKER: RLS applies).
create or replace function public.giving_summary()
returns table (total_year numeric, gifts_year bigint, total_all numeric)
language sql stable set search_path = public as $$
  select
    coalesce(sum(amount) filter (where date >= date_trunc('year', current_date)), 0),
    count(*) filter (where date >= date_trunc('year', current_date)),
    coalesce(sum(amount), 0)
  from donations
$$;
revoke execute on function public.giving_summary() from anon, public;

-- ============ Org donation link ============================================
alter table public.tenants add column donation_url text;

-- ============ Client error log (insert-only for signed-in users) ==========
create table public.client_errors (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade,
  message text not null,
  stack text,
  url text,
  user_agent text,
  created_at timestamptz not null default now()
);
alter table public.client_errors enable row level security;
create policy insert_own on public.client_errors
  for insert to authenticated with check (true);
create index client_errors_tenant_idx on public.client_errors (tenant_id);
create trigger trg_client_errors_tenant
  before insert on public.client_errors
  for each row execute function set_tenant_id();
