-- Enqueue autopilot occasions for the next 2 days. Timezone→UTC conversion
-- happens in SQL (correct + DST-aware). Idempotent via the unique index.
-- Only opted-in, active donors with a phone AND a known timezone qualify.
create or replace function public.enqueue_autopilot()
returns int language plpgsql security definer set search_path to 'public' as $$
declare inserted int := 0;
begin
  insert into scheduled_messages
    (tenant_id, donor_id, send_at, body, video_path, occasion, source)
  select t.id, d.id,
         ((occ.next_date + make_interval(hours => t.autosend_hour::int))
            at time zone d.timezone) as send_at,
         replace(
           coalesce(nullif(r.body_template, ''),
             case occ.occasion
               when 'birthday' then 'Happy birthday, {first_name}! 🎉 So grateful for you.'
               when 'giving_anniversary' then 'Thank you for your faithful giving, {first_name} — it means the world.'
               else 'Thinking of you today, {first_name}!' end),
           '{first_name}', coalesce(nullif(d.preferred_name,''), d.first_name)),
         r.video_path, occ.occasion, 'autopilot'
  from tenants t
  join autopilot_rules r on r.tenant_id = t.id and r.enabled
  join donors d on d.tenant_id = t.id and d.status = 'active'
       and d.consent_status = 'opted_in' and d.timezone is not null
       and d.phone_e164 is not null
  join lateral (
    select kd.type::text as occasion,
           ( select case
               when make_date(extract(year from current_date)::int, mo, dy) >= current_date
                 then make_date(extract(year from current_date)::int, mo, dy)
               else make_date(extract(year from current_date)::int + 1, mo, dy) end
             from (select extract(month from kd.date)::int as mo,
                          case when extract(month from kd.date)=2 and extract(day from kd.date)=29
                               then 28 else extract(day from kd.date)::int end as dy) m
           ) as next_date
    from key_dates kd
    where kd.donor_id = d.id and kd.type::text = r.occasion
  ) occ on occ.next_date is not null
       and occ.next_date >= current_date
       and occ.next_date <= current_date + 2
  where t.autosend_enabled
  on conflict (donor_id, occasion, send_at) do nothing;
  get diagnostics inserted = row_count;
  return inserted;
end $$;

-- Cron calls the SQL function directly (no edge fn needed for enqueue).
select cron.unschedule('autopilot-enqueue');
select cron.schedule('autopilot-enqueue', '10 * * * *',
  $$ select public.enqueue_autopilot(); $$);
