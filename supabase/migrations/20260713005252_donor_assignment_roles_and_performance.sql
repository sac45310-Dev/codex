-- Donor portfolios: a Fundraiser (owns the relationship/giving; existing
-- assigned_to) plus an optional Donor Support person (the VIP "handler").
-- Plus a per-org toggle to default the dashboard to "my donors", and a
-- team-performance rollup.
alter table donors
  add column if not exists support_user_id uuid references users(id) on delete set null,
  add column if not exists assigned_at timestamptz,
  add column if not exists support_assigned_at timestamptz;

create index if not exists donors_assigned_to_idx on donors (tenant_id, assigned_to);
create index if not exists donors_support_user_idx on donors (tenant_id, support_user_id);

-- Stamp assignment timestamps when the assignee changes (for "growth since
-- assigned" later). Runs in the tenant's own security context; no RLS issue.
create or replace function stamp_assignment() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to then
    new.assigned_at := case when new.assigned_to is not null then now() end;
  end if;
  if tg_op = 'INSERT' or new.support_user_id is distinct from old.support_user_id then
    new.support_assigned_at := case when new.support_user_id is not null then now() end;
  end if;
  return new;
end $$;
drop trigger if exists trg_stamp_assignment on donors;
create trigger trg_stamp_assignment before insert or update on donors
  for each row execute function stamp_assignment();

alter table tenants
  add column if not exists filter_by_assignee boolean not null default false;

-- Per-team-member scoreboard for the caller's tenant: portfolio = donors
-- where the member is the Fundraiser OR the Donor Support, with giving
-- growth (this vs last year) and relationship activity.
create or replace function team_performance()
returns table (
  user_id uuid, name text, email text, role text,
  fundraiser_donors bigint, support_donors bigint,
  giving_this_year numeric, giving_last_year numeric, growth_pct numeric,
  messages_30d bigint, last_contact timestamptz
) language plpgsql stable security definer set search_path to 'public' as $$
declare v_tenant uuid := auth_tenant_id();
begin
  if v_tenant is null then raise exception 'No tenant'; end if;
  return query
  with portfolio as (
    select u.id as uid, u.name, u.email, u.role::text as role, d.id as donor_id,
           (d.assigned_to = u.id) as is_fundraiser,
           (d.support_user_id = u.id) as is_support
    from users u
    left join donors d
      on d.tenant_id = v_tenant and d.status = 'active'
     and (d.assigned_to = u.id or d.support_user_id = u.id)
    where u.tenant_id = v_tenant
  ),
  gifts as (
    select p.uid,
      sum(g.amount) filter (where date_trunc('year', g.date) = date_trunc('year', now())) as ty,
      sum(g.amount) filter (where date_trunc('year', g.date) = date_trunc('year', now()) - interval '1 year') as ly
    from portfolio p
    join donations g on g.donor_id = p.donor_id
    group by p.uid
  ),
  msgs as (
    select m.sent_by as uid,
      count(*) filter (where m.created_at > now() - interval '30 days') as m30,
      max(m.created_at) as last_c
    from messages m where m.tenant_id = v_tenant and m.direction = 'outbound'
    group by m.sent_by
  )
  select p.uid, p.name, p.email, p.role,
    count(distinct p.donor_id) filter (where p.is_fundraiser),
    count(distinct p.donor_id) filter (where p.is_support),
    coalesce(gf.ty, 0), coalesce(gf.ly, 0),
    case when coalesce(gf.ly,0) = 0 then null
         else round((coalesce(gf.ty,0) - gf.ly) / gf.ly * 100, 0) end,
    coalesce(ms.m30, 0), ms.last_c
  from portfolio p
  left join gifts gf on gf.uid = p.uid
  left join msgs ms on ms.uid = p.uid
  group by p.uid, p.name, p.email, p.role, gf.ty, gf.ly, ms.m30, ms.last_c
  order by coalesce(gf.ty,0) desc, p.name;
end $$;
