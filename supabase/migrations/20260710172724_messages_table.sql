create table public.messages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  donor_id uuid not null references public.donors(id) on delete cascade,
  direction text not null check (direction in ('outbound', 'inbound')),
  channel channel not null default 'sms',
  body text not null,
  status text not null default 'queued',  -- queued | sent | delivered | failed | received
  provider_sid text,
  error text,
  sent_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

create policy tenant_isolation on public.messages
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create index messages_tenant_idx on public.messages (tenant_id);
create index messages_donor_idx on public.messages (donor_id, created_at desc);
create index messages_sent_by_idx on public.messages (sent_by);

create trigger trg_messages_tenant
  before insert on public.messages
  for each row execute function set_tenant_id();
