-- CLAUDE.md hard rule 1 was enforceable only by convention: a tenant user
-- could PATCH donors.consent_status directly via PostgREST, bypassing the
-- record_consent audit trail (caught by the security suite). Close it:
-- record_consent becomes SECURITY DEFINER (with an explicit tenant guard,
-- since definer bypasses RLS), then the direct column writes are revoked.

create or replace function public.record_consent(
  p_donor_id uuid, p_status consent_status, p_source text,
  p_channel channel default null::channel)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- DEFINER bypasses RLS, so verify the donor is in the caller's tenant
  -- (auth_tenant_id resolves the shadowed tenant for support staff).
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
  update public.donors
     set consent_status = p_status, consent_source = p_source, consent_updated_at = now()
   where id = p_donor_id and tenant_id = auth_tenant_id();
end $function$;

-- Now that the RPC writes as definer, remove the direct-write grants so the
-- ONLY path to consent columns is the audited RPC. SELECT/INSERT stay
-- (a new donor's initial consent_status is set on insert; the RPC handles
-- every change thereafter). The service role (inbound webhook) is unaffected.
revoke update (consent_status, consent_source, consent_updated_at)
  on public.donors from authenticated, anon;
