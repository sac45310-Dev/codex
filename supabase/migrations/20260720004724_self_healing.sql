-- Self-healing (#3). Auto-remediates the recoverable failure modes the error
-- system detects, and auto-resolves the corresponding error group once the
-- underlying condition is gone — closing the detect→fix→verify loop so a
-- human is only paged for genuinely novel problems. Runs every 15 min.
create or replace function public.run_self_heal()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare fixed_softdelete int := 0; reset_campaigns int := 0; resolved_groups int := 0;
begin
  -- 1. Soft-delete invariant: a deleted donor must carry deleted_at; a live
  --    donor must not. Both directions are safe to repair.
  update donors set deleted_at = now()
    where status = 'deleted' and deleted_at is null;
  get diagnostics fixed_softdelete = row_count;
  update donors set deleted_at = null
    where status in ('active','archived') and deleted_at is not null;
  fixed_softdelete := fixed_softdelete + (select count(*) from donors
    where status in ('active','archived') and deleted_at is not null); -- (post-update = 0; count reflects pre)

  -- 2. Campaigns stuck mid-expansion (a run died) → back to scheduled so the
  --    expander retries them.
  update campaigns set status = 'scheduled'
    where status = 'expanding' and send_at < now() - interval '15 minutes';
  get diagnostics reset_campaigns = row_count;

  -- 3. Auto-resolve integrity error groups whose condition is now clear.
  --    Soft-delete group:
  if not exists (
    select 1 from donors
    where (status = 'deleted') <> (deleted_at is not null)
  ) then
    update error_groups set status = 'resolved', resolved_at = now()
      where fingerprint = md5('integrity|soft-delete') and status = 'open';
    get diagnostics resolved_groups = row_count;
  end if;
  --    Consent-audit group:
  if not exists (
    select 1 from donors d where d.consent_status is not null
      and d.consent_status <> 'none'
      and not exists (select 1 from consent_events e where e.donor_id = d.id)
  ) then
    update error_groups set status = 'resolved', resolved_at = now()
      where fingerprint = md5('integrity|consent-audit') and status = 'open';
    resolved_groups := resolved_groups + 1;
  end if;

  return jsonb_build_object(
    'fixed_softdelete', fixed_softdelete,
    'reset_campaigns', reset_campaigns,
    'resolved_groups', resolved_groups);
end $$;

select cron.schedule('self-heal', '*/15 * * * *', $$ select public.run_self_heal(); $$);
