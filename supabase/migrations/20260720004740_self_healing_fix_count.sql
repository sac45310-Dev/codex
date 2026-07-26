create or replace function public.run_self_heal()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare a int := 0; b int := 0; reset_campaigns int := 0; resolved_groups int := 0;
begin
  update donors set deleted_at = now()
    where status = 'deleted' and deleted_at is null;
  get diagnostics a = row_count;
  update donors set deleted_at = null
    where status in ('active','archived') and deleted_at is not null;
  get diagnostics b = row_count;

  update campaigns set status = 'scheduled'
    where status = 'expanding' and send_at < now() - interval '15 minutes';
  get diagnostics reset_campaigns = row_count;

  if not exists (select 1 from donors where (status='deleted') <> (deleted_at is not null)) then
    update error_groups set status='resolved', resolved_at=now()
      where fingerprint = md5('integrity|soft-delete') and status='open';
    get diagnostics resolved_groups = row_count;
  end if;
  if not exists (
    select 1 from donors d where d.consent_status is not null and d.consent_status <> 'none'
      and not exists (select 1 from consent_events e where e.donor_id = d.id)
  ) then
    update error_groups set status='resolved', resolved_at=now()
      where fingerprint = md5('integrity|consent-audit') and status='open';
    resolved_groups := resolved_groups + coalesce((select 1),0);
  end if;

  return jsonb_build_object('fixed_softdelete', a + b,
    'reset_campaigns', reset_campaigns, 'resolved_groups', resolved_groups);
end $$;
select public.run_self_heal() as heal_result;
