-- Security hardening (SECURITY.md) — closes the Supabase advisor findings
-- that are safe to remediate without behavior change.

alter function public.stamp_assignment() set search_path = public;
alter function public.generate_referral_code() set search_path = public;
alter function public.donation_page_slug_guard() set search_path = public;
alter function public.error_fingerprint(text, text) set search_path = public;

do $$
declare f text;
begin
  foreach f in array array[
    'set_tenant_id()', 'log_activity()', 'stamp_assignment()',
    'enforce_donor_cap()', 'enforce_seat_cap()', 'enforce_donation_page_flag()',
    'guard_plan_edit()', 'protect_billing_columns()', 'donation_page_slug_guard()',
    'error_event_ingest()',
    'error_fingerprint(text, text)', 'run_integrity_sweep()',
    'log_platform_event(uuid, text, text)', 'assert_staff_manager()',
    'generate_referral_code()'
  ] loop
    execute format('revoke execute on function public.%s from anon, authenticated', f);
  end loop;
end $$;

drop policy if exists "donor photos public read" on storage.objects;
drop policy if exists "donor videos public read" on storage.objects;
drop policy if exists "donation pages public read" on storage.objects;
