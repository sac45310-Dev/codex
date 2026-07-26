alter table public.tenants
  add column if not exists monthly_goal numeric
    check (monthly_goal is null or monthly_goal > 0);

create or replace function public.funding_progress()
returns table (
  goal numeric,
  this_month numeric,
  last_month numeric,
  pledged_monthly numeric,
  months jsonb,
  streak_weeks int,
  touched_quarter_pct int
)
language sql
stable
set search_path = public
as $$
  with gifts as (
    select
      coalesce(sum(amount) filter (
        where date >= date_trunc('month', current_date)), 0) as this_month,
      coalesce(sum(amount) filter (
        where date >= date_trunc('month', current_date) - interval '1 month'
          and date < date_trunc('month', current_date)), 0) as last_month
    from donations
  ),
  pledged as (
    select coalesce(sum(case pledge_frequency
      when 'monthly' then pledge_amount
      when 'quarterly' then pledge_amount / 3
      when 'annually' then pledge_amount / 12
    end), 0) as monthly
    from donors
    where status = 'active' and pledge_amount is not null
  ),
  month_axis as (
    select gs as m
    from generate_series(
      date_trunc('month', current_date) - interval '5 months',
      date_trunc('month', current_date), interval '1 month') gs
  ),
  month_totals as (
    select date_trunc('month', date) as m, sum(amount) as total
    from donations
    where date >= (date_trunc('month', current_date) - interval '5 months')::date
    group by 1
  ),
  series as (
    select jsonb_agg(jsonb_build_object(
      'month', to_char(month_axis.m, 'YYYY-MM'),
      'total', coalesce(month_totals.total, 0)) order by month_axis.m) as months
    from month_axis
    left join month_totals on month_totals.m = month_axis.m
  ),
  wk_list as (
    select distinct date_trunc('week', created_at) as wk
    from messages
    where direction = 'outbound'
  ),
  anchor as (
    select case
      when exists (select 1 from wk_list where wk = date_trunc('week', now()))
        then date_trunc('week', now())
      else date_trunc('week', now()) - interval '1 week'
    end as a
  ),
  streak as (
    select count(*)::int as weeks
    from (
      select wk, row_number() over (order by wk desc) - 1 as i
      from wk_list, anchor
      where wk <= anchor.a
    ) x, anchor
    where x.wk = anchor.a - (x.i * interval '1 week')
  ),
  touched as (
    select
      count(*) filter (where t.donor_id is not null)::int as touched,
      count(*)::int as total
    from donors dn
    left join (
      select distinct donor_id
      from messages
      where direction = 'outbound'
        and created_at >= date_trunc('quarter', now())
    ) t on t.donor_id = dn.id
    where dn.status = 'active'
  )
  select
    (select monthly_goal from tenants limit 1) as goal,
    gifts.this_month,
    gifts.last_month,
    pledged.monthly as pledged_monthly,
    series.months,
    streak.weeks as streak_weeks,
    case when touched.total = 0 then 0
         else (touched.touched * 100 / touched.total) end as touched_quarter_pct
  from gifts, pledged, series, streak, touched
$$;

revoke execute on function public.funding_progress() from public, anon;
grant execute on function public.funding_progress() to authenticated;
