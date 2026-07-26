-- Inbox conversation list: one row per donor with messages — newest first,
-- with unread counts. RLS-scoped to the caller's tenant via auth_tenant_id.
create or replace function public.get_conversations()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_tenant uuid := auth_tenant_id();
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  return coalesce((
    select jsonb_agg(c order by (c->>'last_at') desc) from (
      select jsonb_build_object(
        'donor_id', d.id,
        'first_name', d.first_name,
        'last_name', d.last_name,
        'phone_e164', d.phone_e164,
        'consent_status', d.consent_status,
        'last_body', m.body,
        'last_direction', m.direction,
        'last_at', m.created_at,
        'unread', (select count(*) from messages u
          where u.tenant_id = v_tenant and u.donor_id = d.id
            and u.direction = 'inbound' and u.read_at is null)
      ) as c
      from donors d
      join lateral (
        select body, direction, created_at from messages
        where tenant_id = v_tenant and donor_id = d.id
        order by created_at desc limit 1
      ) m on true
      where d.tenant_id = v_tenant and d.status <> 'deleted'
    ) sub
  ), '[]'::jsonb);
end $$;
revoke execute on function public.get_conversations() from public, anon;
