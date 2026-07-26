alter table public.platform_staff add column if not exists username text;
create unique index if not exists platform_staff_username_uniq
  on public.platform_staff (lower(username)) where username is not null;

update public.platform_staff ps
   set username = coalesce(
     nullif(regexp_replace(lower(split_part(u.name, ' ', 1)), '[^a-z0-9_.]', '', 'g'), ''),
     split_part(u.email, '@', 1))
  from public.users u
 where u.id = ps.user_id and ps.username is null;

create or replace function sales.owner_label(p_email text)
returns text language sql stable security definer
set search_path to 'public','sales' as $$
  select coalesce(
    (select ps.username from public.platform_staff ps
       join public.users u on u.id = ps.user_id
      where lower(u.email) = lower(p_email) and ps.username is not null
      limit 1),
    nullif(split_part(coalesce(p_email,''), '@', 1), ''),
    p_email)
$$;

create or replace function public.admin_set_username(p_username text)
returns text language plpgsql security definer
set search_path to 'public' as $$
declare v_clean text;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  v_clean := regexp_replace(lower(btrim(coalesce(p_username,''))), '[^a-z0-9_.]', '', 'g');
  if length(v_clean) < 2 then
    raise exception 'Username must be at least 2 characters (letters, numbers, _ or .)'; end if;
  if exists (select 1 from public.platform_staff
             where lower(username) = v_clean and user_id <> auth.uid()) then
    raise exception 'That username is already taken'; end if;
  update public.platform_staff set username = v_clean where user_id = auth.uid();
  return v_clean;
end $$;
revoke execute on function public.admin_set_username(text) from public, anon;
grant execute on function public.admin_set_username(text) to authenticated;

create or replace function public.get_platform_context()
returns json language sql stable security definer
set search_path to 'public' as $$
  select case when platform_role() is null then null else json_build_object(
    'role', platform_role(),
    'username', (select username from platform_staff where user_id = auth.uid()),
    'shadow', (
      select json_build_object(
        'tenant_id', t.id, 'legal_name', t.legal_name,
        'is_override', s.is_override, 'started_at', s.started_at,
        'mode', s.mode,
        'locale', t.locale, 'currency', t.currency,
        'donation_url', t.donation_url
      )
      from support_sessions s join tenants t on t.id = s.tenant_id
      where s.tenant_id = active_shadow_tenant()
        and s.staff_user_id = auth.uid() and s.ended_at is null
      order by s.started_at desc limit 1
    )
  ) end
$$;
