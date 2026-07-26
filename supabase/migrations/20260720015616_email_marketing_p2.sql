-- Email marketing Phase 2: per-org kill switch when complaints spike.
alter table public.tenants add column if not exists email_paused boolean not null default false;

-- Suppress an address + (for complaints) opt the donor out, from the webhook
-- (service role). Idempotent.
create or replace function public.email_suppress(p_tenant uuid, p_email text, p_reason text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  insert into email_suppressions (tenant_id, email, reason)
  values (p_tenant, lower(p_email), p_reason)
  on conflict (tenant_id, email) do nothing;
  if p_reason = 'complaint' then
    update donors set email_opt_out = true
      where tenant_id = p_tenant and lower(email) = lower(p_email);
  end if;
end $$;
revoke execute on function public.email_suppress(uuid, text, text) from public, anon, authenticated;
