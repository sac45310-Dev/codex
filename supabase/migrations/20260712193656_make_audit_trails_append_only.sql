-- Audit integrity: consent_events (legal consent record) and activity_log
-- must be append-only for clients. consent_events has a permissive ALL
-- policy (tenant members could UPDATE/DELETE rows); add restrictive deny
-- policies so only INSERT + SELECT survive. The record_consent RPC and the
-- activity triggers write as SECURITY DEFINER (table owner) and bypass RLS,
-- so legitimate writes are unaffected; FK cascade on donor delete also
-- bypasses RLS, so donor deletion still cleans up child rows.
create policy append_only_no_update on consent_events
  as restrictive for update using (false);
create policy append_only_no_delete on consent_events
  as restrictive for delete using (false);

-- activity_log already has no permissive write policy (append-only in
-- practice); make the intent explicit and future-proof.
create policy append_only_no_update on activity_log
  as restrictive for update using (false);
create policy append_only_no_delete on activity_log
  as restrictive for delete using (false);
