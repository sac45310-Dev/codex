-- Twilio signs webhooks with the auth token of the account that OWNS the
-- number — for per-tenant subaccount numbers that's the subaccount token,
-- so it must be stored at creation time (service-role-only table; clients
-- can only SELECT their own row and this column is stripped in the UI RPC
-- path — the Settings page reads status/number fields only).
alter table public.sms_provisioning add column twilio_subaccount_token text;
