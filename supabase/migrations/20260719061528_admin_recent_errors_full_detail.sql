-- Full error detail for the console's error triage view: complete message,
-- stack trace, and user agent — enough to paste into an AI session and fix.
create or replace function public.admin_recent_errors(p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(), '') not in ('owner', 'support', 'billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((
    select jsonb_agg(e order by (e->>'created_at') desc) from (
      select jsonb_build_object(
        'message', ce.message,
        'stack', left(ce.stack, 2000),
        'user_agent', ce.user_agent,
        'url', ce.url,
        'org', t.legal_name,
        'created_at', ce.created_at
      ) as e
      from client_errors ce
      left join tenants t on t.id = ce.tenant_id
      order by ce.created_at desc
      limit least(p_limit, 200)
    ) sub
  ), '[]'::jsonb);
end $$;
