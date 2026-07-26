create or replace function public.sales_e2e_cleanup(p_org_name text)
returns json
language plpgsql
security definer
set search_path to 'public', 'sales'
as $$
declare
  c_prefix constant text := 'E2E Scout ';
  v_leads  integer := 0;
  v_cands  integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and coalesce(platform_role(), '') = '' then
    raise exception 'Not authorized';
  end if;

  if p_org_name is null or left(p_org_name, length(c_prefix)) <> c_prefix then
    raise exception 'sales_e2e_cleanup only accepts names starting with "%"', c_prefix;
  end if;

  delete from sales.leads where org_name = p_org_name;
  get diagnostics v_leads = row_count;

  delete from sales.scout_candidates where org_name = p_org_name;
  get diagnostics v_cands = row_count;

  return json_build_object('leads_deleted', v_leads, 'candidates_deleted', v_cands);
end $$;

revoke execute on function public.sales_e2e_cleanup(text) from public, anon;
grant execute on function public.sales_e2e_cleanup(text) to authenticated, service_role;
