-- Column-level grants: tenant admins may watch their provisioning status,
-- but the Twilio SIDs/token are operational secrets — with the subaccount
-- token a tenant could call Twilio directly and bypass the server-side
-- consent gate in send-sms. RLS is row-level only, so restrict columns.
revoke select on public.sms_provisioning from authenticated;
grant select (id, tenant_id, status, phone_number, rejection_reason,
  business_info, grace_started_at, created_at, updated_at)
  on public.sms_provisioning to authenticated;
