-- Donor health for background jobs (weekly digest). donor_health() runs as
-- INVOKER under RLS, which service-role cron code can't use (no tenant
-- scope). This variant takes the tenant explicitly, filters every table by
-- it, and guards: service_role (cron/digest) or a member of that tenant.
-- Same risk rules as donor_health() — keep the two in lockstep.
create or replace function public.donor_health_for_tenant(p_tenant_id uuid)
returns table (
  donor_id uuid,
  first_name text,
  preferred_name text,
  last_name text,
  risk text,
  last_gift_date date,
  last_gift_amount numeric,
  gave_last_year numeric,
  last_touch_at timestamptz,
  avg_gap_days int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (auth.role() = 'service_role' or p_tenant_id = auth_tenant_id()) then
    raise exception 'not allowed';
  end if;
  return query
  with g as (
    select d.donor_id,
           max(d.date) as last_gift_date,
           (array_agg(d.amount order by d.date desc))[1] as last_gift_amount,
           coalesce(sum(d.amount) filter (
             where extract(year from d.date) = extract(year from current_date) - 1), 0) as gave_last_year,
           coalesce(sum(d.amount) filter (
             where extract(year from d.date) = extract(year from current_date)), 0) as gave_this_year,
           coalesce(sum(d.amount) filter (where d.date >= current_date - 365), 0) as gave_12mo,
           count(*) filter (where d.date >= current_date - 365) as gifts_12mo
    from donations d
    where d.tenant_id = p_tenant_id and d.donor_id is not null
    group by d.donor_id
  ),
  gaps as (
    select x.donor_id, avg(x.gap)::int as avg_gap_days
    from (
      select d.donor_id,
             d.date - lag(d.date) over (partition by d.donor_id order by d.date) as gap,
             row_number() over (partition by d.donor_id order by d.date desc) as rn
      from donations d
      where d.tenant_id = p_tenant_id and d.donor_id is not null
    ) x
    where x.rn <= 4 and x.gap is not null and x.gap > 0
    group by x.donor_id
  ),
  t as (
    select m.donor_id, max(m.created_at) as last_touch_at
    from messages m
    where m.tenant_id = p_tenant_id and m.direction = 'outbound'
    group by m.donor_id
  ),
  scored as (
    select
      dn.id as donor_id,
      dn.first_name, dn.preferred_name, dn.last_name,
      case
        when gaps.avg_gap_days between 20 and 40
             and g.gifts_12mo >= 3
             and g.last_gift_date < current_date - (gaps.avg_gap_days * 3 / 2)
          then 'lapsed_recurring'
        when g.gave_last_year > 0 and g.gave_this_year = 0
             and g.last_gift_date < current_date - 90
          then 'lybunt'
        when g.gave_12mo > 0
             and (t.last_touch_at is null or t.last_touch_at < now() - interval '60 days')
          then 'no_touch'
      end as risk,
      g.last_gift_date, g.last_gift_amount, g.gave_last_year,
      t.last_touch_at, gaps.avg_gap_days,
      greatest(g.gave_12mo, g.gave_last_year) as at_stake
    from donors dn
    join g on g.donor_id = dn.id
    left join gaps on gaps.donor_id = dn.id
    left join t on t.donor_id = dn.id
    where dn.tenant_id = p_tenant_id and dn.status = 'active'
  )
  select s.donor_id, s.first_name, s.preferred_name, s.last_name,
         s.risk, s.last_gift_date, s.last_gift_amount, s.gave_last_year,
         s.last_touch_at, s.avg_gap_days
  from scored s
  where s.risk is not null
  order by array_position(array['lapsed_recurring','lybunt','no_touch'], s.risk),
           s.at_stake desc nulls last
  limit 30;
end;
$$;

revoke execute on function public.donor_health_for_tenant(uuid) from public, anon;
grant execute on function public.donor_health_for_tenant(uuid) to authenticated, service_role;
