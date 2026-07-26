create or replace function public.us_timezone(p_state text)
returns text language sql immutable as $$
  select case upper(coalesce(p_state, ''))
    when 'CA' then 'America/Los_Angeles' when 'WA' then 'America/Los_Angeles'
    when 'OR' then 'America/Los_Angeles' when 'NV' then 'America/Los_Angeles'
    when 'AZ' then 'America/Phoenix'
    when 'MT' then 'America/Denver' when 'ID' then 'America/Denver'
    when 'WY' then 'America/Denver' when 'UT' then 'America/Denver'
    when 'CO' then 'America/Denver' when 'NM' then 'America/Denver'
    when 'ND' then 'America/Chicago' when 'SD' then 'America/Chicago'
    when 'NE' then 'America/Chicago' when 'KS' then 'America/Chicago'
    when 'OK' then 'America/Chicago' when 'TX' then 'America/Chicago'
    when 'MN' then 'America/Chicago' when 'IA' then 'America/Chicago'
    when 'MO' then 'America/Chicago' when 'AR' then 'America/Chicago'
    when 'LA' then 'America/Chicago' when 'WI' then 'America/Chicago'
    when 'IL' then 'America/Chicago' when 'MS' then 'America/Chicago'
    when 'AL' then 'America/Chicago' when 'TN' then 'America/Chicago'
    when 'AK' then 'America/Anchorage' when 'HI' then 'Pacific/Honolulu'
    when 'MI' then 'America/New_York' when 'IN' then 'America/New_York'
    when 'KY' then 'America/New_York' when 'OH' then 'America/New_York'
    when 'GA' then 'America/New_York' when 'FL' then 'America/New_York'
    when 'SC' then 'America/New_York' when 'NC' then 'America/New_York'
    when 'VA' then 'America/New_York' when 'WV' then 'America/New_York'
    when 'PA' then 'America/New_York' when 'NY' then 'America/New_York'
    when 'DC' then 'America/New_York' when 'MD' then 'America/New_York'
    when 'DE' then 'America/New_York' when 'NJ' then 'America/New_York'
    when 'CT' then 'America/New_York' when 'RI' then 'America/New_York'
    when 'MA' then 'America/New_York' when 'VT' then 'America/New_York'
    when 'NH' then 'America/New_York' when 'ME' then 'America/New_York'
    else null end;
$$;

create or replace function public.fill_donor_timezone()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.timezone is null and new.state is not null then
    new.timezone := us_timezone(new.state);
  end if;
  return new;
end $$;
drop trigger if exists trg_fill_donor_timezone on public.donors;
create trigger trg_fill_donor_timezone
  before insert or update of state, timezone on public.donors
  for each row execute function fill_donor_timezone();
update public.donors set timezone = us_timezone(state)
  where timezone is null and state is not null;

alter table public.tenants
  add column autosend_enabled boolean not null default false,
  add column autosend_hour smallint not null default 9
    check (autosend_hour between 0 and 23);

create table public.autopilot_rules (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  occasion text not null check (occasion in
    ('birthday','giving_anniversary','ministry_anniversary')),
  enabled boolean not null default false,
  video_path text,
  body_template text,
  primary key (tenant_id, occasion)
);
alter table public.autopilot_rules enable row level security;
create policy tenant_isolation on public.autopilot_rules
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create table public.scheduled_messages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  donor_id uuid not null references public.donors(id) on delete cascade,
  send_at timestamptz not null,
  body text not null,
  video_path text,
  occasion text,
  source text not null default 'autopilot'
    check (source in ('autopilot','campaign','manual')),
  campaign_id uuid,
  status text not null default 'scheduled'
    check (status in ('scheduled','sent','failed','canceled','skipped')),
  attempts int not null default 0,
  last_error text,
  message_id uuid,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (donor_id, occasion, send_at)
);
alter table public.scheduled_messages enable row level security;
create policy tenant_isolation on public.scheduled_messages
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create index scheduled_messages_due_idx
  on public.scheduled_messages (status, send_at);
create trigger trg_scheduled_messages_tenant
  before insert on public.scheduled_messages
  for each row execute function set_tenant_id();

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  body text not null,
  video_path text,
  segment_id uuid references public.segments(id) on delete set null,
  send_at timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('draft','scheduled','expanding','sent','canceled')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expanded_at timestamptz
);
alter table public.campaigns enable row level security;
create policy tenant_isolation on public.campaigns
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create trigger trg_campaigns_tenant
  before insert on public.campaigns
  for each row execute function set_tenant_id();

select cron.schedule('autopilot-enqueue', '10 * * * *', $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/autopilot-enqueue',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key='cron_secret')),
    body := '{"action":"cron"}'::jsonb);
$$);
select cron.schedule('message-sender', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/message-sender',
    headers := jsonb_build_object('Content-Type','application/json',
      'x-cron-secret', (select value from app_config where key='cron_secret')),
    body := '{"action":"cron"}'::jsonb);
$$);
