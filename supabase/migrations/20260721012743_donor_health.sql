-- Donor health & at-risk alerts (F2, 2026-07-22). One RPC computes the
-- "Needs attention" list server-side (no client N+1): donors slipping away
-- ranked by how much money+relationship is at stake. Runs as INVOKER so
-- donors/donations/messages RLS scopes everything to the caller's tenant.
--
-- Risk types (first match wins, most urgent first):
--  * lapsed_recurring — a monthly-cadence giver (avg gap of the last 4
--    gifts 20-40d, 3+ gifts in 12mo) whose next gift is >1.5x overdue
--  * lybunt — gave last calendar year, nothing this year (classic
--    "Last Year But Unfortunately Not This"); only flagged once the last
--    gift is 90+ days back so January isn't all noise
--  * no_touch — an active giver (gave in the last 12mo) with no outbound
--    message in 60+ days (or ever) — the relationship is going cold
create or replace function public.donor_health()
returns table (
  donor_id uuid,
  first_name text,
  preferred_name text,
  last_name text,
  photo_url text,
  phone_e164 text,
  consent_status text,
  assigned_to uuid,
  support_user_id uuid,
  risk text,
  last_gift_date date,
  last_gift_amount numeric,
  gave_last_year numeric,
  last_touch_at timestamptz,
  avg_gap_days int
)
language sql
stable
set search_path = public
as $$
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
    where d.donor_id is not null
    group by d.donor_id
  ),
  gaps as (
    select x.donor_id, avg(x.gap)::int as avg_gap_days
    from (
      select d.donor_id,
             d.date - lag(d.date) over (partition by d.donor_id order by d.date) as gap,
             row_number() over (partition by d.donor_id order by d.date desc) as rn
      from donations d
      where d.donor_id is not null
    ) x
    where x.rn <= 4 and x.gap is not null and x.gap > 0
    group by x.donor_id
  ),
  t as (
    select m.donor_id, max(m.created_at) as last_touch_at
    from messages m
    where m.direction = 'outbound'
    group by m.donor_id
  ),
  scored as (
    select
      dn.id as donor_id,
      dn.first_name, dn.preferred_name, dn.last_name,
      dn.photo_url, dn.phone_e164, dn.consent_status,
      dn.assigned_to, dn.support_user_id,
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
    where dn.status = 'active'
  )
  select donor_id, first_name, preferred_name, last_name, photo_url,
         phone_e164, consent_status, assigned_to, support_user_id,
         risk, last_gift_date, last_gift_amount, gave_last_year,
         last_touch_at, avg_gap_days
  from scored
  where risk is not null
  order by array_position(array['lapsed_recurring','lybunt','no_touch'], risk),
           at_stake desc nulls last
  limit 30
$$;

revoke execute on function public.donor_health() from public, anon;
grant execute on function public.donor_health() to authenticated;
