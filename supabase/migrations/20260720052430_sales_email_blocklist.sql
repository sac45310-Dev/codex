-- Privacy blocklist for CRM email capture: emails involving any blocked
-- address/domain are NEVER attached (family, friends, internal HR, etc.).
-- Enforced inside sales_attach_email — the single choke point for both the
-- Gmail sync and the BCC webhook.
create table sales.email_blocklist (
  id uuid primary key default gen_random_uuid(),
  pattern text not null unique,   -- 'a@b.com' exact | '@family.com' or 'family.com' domain
  note text,
  created_by text,
  created_at timestamptz not null default now()
);
alter table sales.email_blocklist enable row level security;

create or replace function sales.is_blocked(p_emails text[])
returns boolean language sql stable as $$
  select exists (
    select 1 from sales.email_blocklist b, unnest(p_emails) e(addr)
    where case
      when b.pattern like '@%' then lower(e.addr) like '%' || lower(b.pattern)
      when position('@' in b.pattern) > 0 then lower(e.addr) = lower(b.pattern)
      else lower(e.addr) like '%@' || lower(b.pattern)
    end
  )
$$;

-- sales_attach_email v2: blocklist check + store recipients in meta (so
-- future blocks can purge accurately).
create or replace function public.sales_attach_email(p json)
returns int language plpgsql security definer
set search_path to 'public','sales' as $$
declare
  v_all_emails text[];
  v_count int := 0;
  v_lead record;
begin
  if coalesce(auth.role(),'') <> 'service_role'
     and coalesce(platform_role(),'') = '' then
    raise exception 'Not authorized';
  end if;

  if exists (select 1 from sales.activities
             where meta->>'msg_id' = p->>'msg_id' and p->>'msg_id' is not null) then
    return 0;
  end if;

  select array_agg(distinct lower(trim(e))) into v_all_emails
  from (
    select p->>'from_email' as e
    union all
    select json_array_elements_text(coalesce(p->'to_emails','[]'::json))
  ) s where e is not null and e <> '';

  -- Privacy: any blocked participant → the email never enters the CRM.
  if sales.is_blocked(v_all_emails) then
    return 0;
  end if;

  for v_lead in
    select distinct c.lead_id, min(c.id::text)::uuid as contact_id
    from sales.contacts c
    where lower(c.email) = any (v_all_emails)
    group by c.lead_id
  loop
    insert into sales.activities (lead_id, contact_id, kind, subject, body, actor_email, meta)
    values (
      v_lead.lead_id, v_lead.contact_id,
      case when p->>'direction' = 'out' then 'email_out' else 'email_in' end,
      left(p->>'subject', 300),
      left(p->>'snippet', 2000),
      p->>'from_email',
      json_build_object('msg_id', p->>'msg_id', 'via', coalesce(p->>'via','email'),
                        'to', coalesce(p->'to_emails','[]'::json))::jsonb
    );
    update sales.leads set updated_at = now() where id = v_lead.lead_id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- Blocklist management (staff-guarded).
create or replace function public.sales_list_blocklist()
returns json language plpgsql stable security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  return coalesce((select json_agg(row_to_json(b) order by b.created_at desc)
                   from sales.email_blocklist b), '[]'::json);
end $$;

-- Adds a block and purges already-captured emails involving the pattern
-- (checks the sender and the stored recipient list). Returns purged count.
create or replace function public.sales_add_block(p_pattern text, p_note text default null)
returns int language plpgsql security definer
set search_path to 'public','sales' as $$
declare v_purged int;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  insert into sales.email_blocklist (pattern, note, created_by)
  values (lower(trim(p_pattern)), p_note, auth.jwt()->>'email')
  on conflict (pattern) do nothing;

  delete from sales.activities a
  where a.kind in ('email_in','email_out')
    and sales.is_blocked(
      array[coalesce(a.actor_email,'')] ||
      coalesce((select array_agg(x) from json_array_elements_text(
        coalesce((a.meta->'to')::json, '[]'::json)) x), '{}'::text[]));
  get diagnostics v_purged = row_count;
  return v_purged;
end $$;

create or replace function public.sales_remove_block(p_id uuid)
returns void language plpgsql security definer
set search_path to 'public','sales' as $$
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  delete from sales.email_blocklist where id = p_id;
end $$;

do $$ declare fn text;
begin
  foreach fn in array array[
    'sales_list_blocklist()', 'sales_add_block(text,text)', 'sales_remove_block(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end $$;
