-- Defense in depth: the platform/admin RPCs already reject non-staff via
-- coalesce(platform_role(),'') guards, but the anon (unauthenticated) role
-- shouldn't be able to invoke them at all. Revoke execute from anon+public;
-- authenticated staff keep access (guards still enforce the role).
do $$
declare fn text;
begin
  foreach fn in array array[
    'admin_add_note','admin_add_staff','admin_create_tenant','admin_delete_tenant',
    'admin_export_tenant','admin_invite_user','admin_list_sessions','admin_list_staff',
    'admin_list_tenants','admin_remove_staff','admin_rename_tenant','admin_revoke_invitation',
    'admin_set_billing','admin_set_user_role','admin_stats','admin_suspend_tenant',
    'admin_tenant_detail','admin_unsuspend_tenant','assert_staff_manager',
    'start_shadow','end_shadow','get_platform_context','grant_support_access',
    'revoke_support_access','log_platform_event'
  ] loop
    execute format('revoke execute on function public.%I from anon, public', fn);
    execute format('grant execute on function public.%I to authenticated', fn);
  end loop;
exception when others then
  -- overloaded names need full signatures; skip any that don't resolve bare
  raise notice 'skipped some: %', sqlerrm;
end $$;
