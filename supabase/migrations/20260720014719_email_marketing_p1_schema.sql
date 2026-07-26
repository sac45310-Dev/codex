-- Email marketing Phase 1 (EMAILS.md). Native bulk email on Resend, sent
-- from a SEPARATE domain (ds-mail.app) so tenant campaign reputation can
-- never poison donorsend.app transactional mail. CAN-SPAM opt-out model for
-- email (vs opt-in for SMS): send to any donor with an email unless they've
-- unsubscribed or been suppressed (hard bounce / complaint).

-- Per-donor email unsubscribe (opt-out) + a one-click token.
alter table public.donors
  add column email_opt_out boolean not null default false,
  add column email_unsub_token uuid not null default gen_random_uuid();

-- Suppression list (hard bounces + spam complaints) — never email again,
-- across ALL campaigns, keyed by address within a tenant.
create table public.email_suppressions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade,
  email text not null,
  reason text not null check (reason in ('bounce','complaint','manual')),
  created_at timestamptz not null default now(),
  unique (tenant_id, email)
);
alter table public.email_suppressions enable row level security;
create policy tenant_read on public.email_suppressions
  for select using (tenant_id = auth_tenant_id());
create trigger trg_email_suppressions_tenant
  before insert on public.email_suppressions
  for each row execute function set_tenant_id();

-- Campaigns gain a channel + email fields (default stays 'sms' so existing
-- SMS campaigns are unaffected).
alter table public.campaigns
  add column channel text not null default 'sms' check (channel in ('sms','email')),
  add column subject text,
  add column stats jsonb not null default '{}'::jsonb; -- sent/opened/etc rollup

-- The shared send queue carries the channel + subject too.
alter table public.scheduled_messages
  add column channel text not null default 'sms' check (channel in ('sms','email')),
  add column subject text;

-- Per-org sending guardrail: a daily email cap (velocity throttle). New/free
-- orgs start conservative; adjustable per tenant.
alter table public.tenants
  add column email_daily_cap int not null default 500;
