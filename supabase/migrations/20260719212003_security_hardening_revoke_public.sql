-- The earlier revoke missed the default PUBLIC grant that anon/authenticated
-- inherit. Revoke from PUBLIC too (RLS-predicate helpers stay untouched).
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
    execute format('revoke execute on function public.%s from public', f);
  end loop;
end $$;
