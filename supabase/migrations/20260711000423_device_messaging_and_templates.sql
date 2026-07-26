-- How a message was sent: 'twilio' (API) or 'device' (handed off to the
-- user's own phone via an sms: link).
alter table public.messages
  add column method text not null default 'twilio'
  check (method in ('twilio', 'device'));

create table public.message_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  body text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.message_templates enable row level security;

create policy tenant_isolation on public.message_templates
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create index message_templates_tenant_idx on public.message_templates (tenant_id);

create trigger trg_message_templates_tenant
  before insert on public.message_templates
  for each row execute function set_tenant_id();
