-- Product analytics (#4). A lightweight event stream + a table-derived
-- activation funnel. The funnel is computed from real tables (reliable even
-- if a client event is missed); events add finer behavioral texture.

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade,
  user_id uuid default auth.uid(),
  event text not null,
  props jsonb,
  created_at timestamptz not null default now()
);
alter table public.analytics_events enable row level security;
-- Insert-only for signed-in users (tenant filled by trigger); no client read.
create policy insert_own on public.analytics_events
  for insert to authenticated with check (true);
create index analytics_events_idx on public.analytics_events (event, created_at desc);
create trigger trg_analytics_events_tenant
  before insert on public.analytics_events
  for each row execute function set_tenant_id();

-- Activation funnel over REAL orgs (excludes @test.internal fixtures/sandbox).
create or replace function public.admin_activation_funnel()
returns jsonb language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if coalesce(platform_role(),'') not in ('owner','support','billing')
     and auth.role() <> 'service_role' then
    raise exception 'Not authorized';
  end if;
  return (
    with real_t as (
      select t.id, t.created_at from tenants t
      where t.onboarded_at is not null and not exists (
        select 1 from users u where u.tenant_id=t.id and u.email ilike '%@test.internal')
    )
    select jsonb_build_object(
      'onboarded', (select count(*) from real_t),
      'added_donor', (select count(distinct d.tenant_id) from donors d join real_t rt on rt.id=d.tenant_id),
      'sent_message', (select count(distinct m.tenant_id) from messages m
          join real_t rt on rt.id=m.tenant_id where m.direction='outbound'),
      'published_giving_page', (select count(distinct p.tenant_id) from donation_pages p
          join real_t rt on rt.id=p.tenant_id where p.published),
      'recorded_gift', (select count(distinct g.tenant_id) from donations g join real_t rt on rt.id=g.tenant_id),
      'events_7d', (select coalesce(jsonb_object_agg(event, n),'{}'::jsonb) from (
          select ae.event, count(*) n from analytics_events ae
          join real_t rt on rt.id=ae.tenant_id
          where ae.created_at > now()-interval '7 days'
          group by ae.event order by count(*) desc limit 15) e)
    )
  );
end $$;
