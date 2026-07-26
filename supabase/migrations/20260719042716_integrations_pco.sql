-- External data integrations (Planning Center Giving first). Credentials
-- are server-only: column-level revoke keeps the PAT out of every client
-- query even though members can see connection status.
create table public.integrations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  provider text not null check (provider in ('planning_center')),
  credentials jsonb,
  status text not null default 'disconnected'
    check (status in ('connected', 'disconnected', 'error')),
  last_synced_at timestamptz,
  last_result text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, provider)
);

alter table public.integrations enable row level security;
create policy tenant_read on public.integrations
  for select using (tenant_id = auth_tenant_id());

revoke select (credentials) on public.integrations from authenticated, anon;

create trigger trg_integrations_tenant
  before insert on public.integrations
  for each row execute function set_tenant_id();

-- Daily incremental sync (same net.http_post + x-cron-secret pattern as the
-- other jobs; the function no-ops when there are no connected integrations).
select cron.schedule(
  'pco-sync-daily',
  '30 7 * * *',
  $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/pco-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select value from app_config where key = 'cron_secret')
    ),
    body := '{"action":"cron"}'::jsonb
  );
  $$
);
