-- Cron-facing variant of sales_today_queue: callable by the service role
-- (edge functions) or platform staff; everyone else is refused. Same shape,
-- no per-user filtering — the edge fn splits per owner.
create or replace function public.sales_cron_queue()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;
  return json_build_object(
    'due', coalesce((select json_agg(row_to_json(x)) from (
      select a.id as activity_id, a.subject, a.body, a.due_at, a.kind,
             l.id as lead_id, l.org_name, l.owner_email
      from sales.activities a join sales.leads l on l.id = a.lead_id
      where a.done_at is null and a.due_at is not null
        and a.due_at < date_trunc('day', now() + interval '1 day')
      order by a.due_at limit 100) x), '[]'::json),
    'stale', coalesce((select json_agg(row_to_json(y)) from (
      select l.id as lead_id, l.org_name, l.owner_email, d.stage, l.updated_at
      from sales.leads l join sales.deals d on d.lead_id = l.id
      where l.status in ('new','researching','qualified')
        and d.stage not in ('won','lost')
        and l.updated_at < now() - interval '7 days'
        and not exists (select 1 from sales.activities a
          where a.lead_id = l.id and a.done_at is null and a.due_at > now())
      order by l.updated_at limit 50) y), '[]'::json));
end $$;
revoke execute on function public.sales_cron_queue() from public, anon;
grant execute on function public.sales_cron_queue() to authenticated, service_role;
