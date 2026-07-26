-- Column-grant revokes are ineffective while authenticated holds a
-- table-level UPDATE on donors. Enforce with a trigger instead, matching
-- the existing protect_billing_columns pattern: consent columns may change
-- only from the service role, platform staff, or our own definer RPC
-- (which sets app.system_write='on').

create or replace function public.protect_consent_columns()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
begin
  if auth.uid() is null or platform_role() is not null
     or coalesce(current_setting('app.system_write', true), '') = 'on' then
    return new; -- service role (inbound webhook), platform staff, or record_consent
  end if;
  if new.consent_status     is distinct from old.consent_status
     or new.consent_source  is distinct from old.consent_source
     or new.consent_updated_at is distinct from old.consent_updated_at then
    raise exception 'Consent is recorded through DonorSend''s consent log and cannot be edited directly.'
      using errcode = 'P0001';
  end if;
  return new;
end $function$;

drop trigger if exists trg_protect_consent_columns on public.donors;
create trigger trg_protect_consent_columns
  before update on public.donors
  for each row execute function public.protect_consent_columns();

-- record_consent (definer) opts into the write via the shared flag.
create or replace function public.record_consent(
  p_donor_id uuid, p_status consent_status, p_source text,
  p_channel channel default null::channel)
returns void
language plpgsql security definer set search_path to 'public'
as $function$
begin
  if not exists (
    select 1 from public.donors
    where id = p_donor_id and tenant_id = auth_tenant_id()
  ) then
    raise exception 'Donor not found in your organization';
  end if;
  if p_status in ('opted_in', 'opted_out') then
    insert into public.consent_events (donor_id, event, source, channel, recorded_by)
    values (p_donor_id,
            case when p_status = 'opted_in' then 'opt_in'::consent_event_type
                 else 'opt_out'::consent_event_type end,
            p_source, p_channel, auth.uid());
  end if;
  perform set_config('app.system_write', 'on', true);
  update public.donors
     set consent_status = p_status, consent_source = p_source, consent_updated_at = now()
   where id = p_donor_id and tenant_id = auth_tenant_id();
end $function$;

-- Restore the harmless column grants (enforcement is the trigger now).
grant update (consent_status, consent_source, consent_updated_at)
  on public.donors to authenticated;
