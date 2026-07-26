-- expand_campaigns() now branches on channel. SMS: phone + opted_in.
-- Email: has an email, not unsubscribed, not suppressed (CAN-SPAM opt-out).
create or replace function public.expand_campaigns()
returns int language plpgsql security definer set search_path to 'public' as $$
declare c record; total int := 0; n int;
begin
  for c in select * from campaigns where status='scheduled' and send_at <= now() + interval '1 hour' loop
    update campaigns set status='expanding' where id=c.id;
    if c.channel = 'email' then
      insert into scheduled_messages
        (tenant_id, donor_id, send_at, body, subject, channel, occasion, source, campaign_id)
      select c.tenant_id, d.id, c.send_at, c.body, c.subject, 'email',
             'campaign:'||left(c.id::text,8), 'campaign', c.id
      from donors d
      where d.tenant_id=c.tenant_id and d.status='active'
        and d.email is not null and d.email_opt_out = false
        and not exists (select 1 from email_suppressions s
          where s.tenant_id=c.tenant_id and lower(s.email)=lower(d.email))
        and (c.segment_id is null or exists (
          select 1 from segment_members sm where sm.segment_id=c.segment_id and sm.donor_id=d.id))
      on conflict (donor_id, occasion, send_at) do nothing;
    else
      insert into scheduled_messages
        (tenant_id, donor_id, send_at, body, video_path, channel, occasion, source, campaign_id)
      select c.tenant_id, d.id, c.send_at, c.body, c.video_path, 'sms',
             'campaign:'||left(c.id::text,8), 'campaign', c.id
      from donors d
      where d.tenant_id=c.tenant_id and d.status='active'
        and d.consent_status='opted_in' and d.phone_e164 is not null
        and (c.segment_id is null or exists (
          select 1 from segment_members sm where sm.segment_id=c.segment_id and sm.donor_id=d.id))
      on conflict (donor_id, occasion, send_at) do nothing;
    end if;
    get diagnostics n = row_count; total := total + n;
    update campaigns set status='sent', expanded_at=now() where id=c.id;
  end loop;
  return total;
end $$;
