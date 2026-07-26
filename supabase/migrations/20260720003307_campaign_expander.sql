-- Expand due campaigns into scheduled_messages (one per opted-in member of
-- the campaign's segment, or ALL opted-in active donors if no segment).
-- Idempotent: the (donor_id, occasion, send_at) unique index + status flip
-- prevent double-expansion. Sends fire via the existing message-sender.
create or replace function public.expand_campaigns()
returns int language plpgsql security definer set search_path to 'public' as $$
declare c record; total int := 0; n int;
begin
  for c in
    select * from campaigns
    where status = 'scheduled' and send_at <= now() + interval '1 hour'
  loop
    update campaigns set status = 'expanding' where id = c.id;
    insert into scheduled_messages
      (tenant_id, donor_id, send_at, body, video_path, occasion, source, campaign_id)
    select c.tenant_id, d.id, c.send_at, c.body, c.video_path,
           'campaign:' || left(c.id::text, 8), 'campaign', c.id
    from donors d
    where d.tenant_id = c.tenant_id
      and d.status = 'active' and d.consent_status = 'opted_in'
      and d.phone_e164 is not null
      and (c.segment_id is null or exists (
        select 1 from segment_members sm
        where sm.segment_id = c.segment_id and sm.donor_id = d.id))
    on conflict (donor_id, occasion, send_at) do nothing;
    get diagnostics n = row_count;
    total := total + n;
    update campaigns set status = 'sent', expanded_at = now() where id = c.id;
  end loop;
  return total;
end $$;

select cron.schedule('campaign-expand', '*/5 * * * *',
  $$ select public.expand_campaigns(); $$);
