-- Short video links: donorsend.app/v/ab12cd34 instead of the full
-- /v?f=<path>&v=<ts> monster. One STABLE code per (tenant, storage path) —
-- re-records update the cache-buster but keep the same short link, so a
-- printed/sent link always shows the latest take.
create table public.video_links (
  code text primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  f text not null,
  v text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, f)
);
alter table public.video_links enable row level security;
create policy tenant_read on public.video_links
  for select using (tenant_id = auth_tenant_id());

-- Create (or refresh) the short link for a video the caller's org owns.
create or replace function public.create_video_link(p_f text, p_v text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare v_tenant uuid := auth_tenant_id(); v_code text; i int := 0;
begin
  if v_tenant is null then raise exception 'Not authorized'; end if;
  -- Videos live under <tenant>/… — refuse codes for other orgs' files.
  if position(v_tenant::text || '/' in p_f) <> 1 then
    raise exception 'Not your video';
  end if;
  update video_links set v = p_v, updated_at = now()
    where tenant_id = v_tenant and f = p_f
    returning code into v_code;
  if found then return v_code; end if;
  loop
    v_code := substr(md5(gen_random_uuid()::text), 1, 8);
    begin
      insert into video_links (code, tenant_id, f, v) values (v_code, v_tenant, p_f, p_v);
      return v_code;
    exception when unique_violation then
      i := i + 1;
      if i > 5 then raise; end if;
    end;
  end loop;
end $$;
revoke execute on function public.create_video_link(text, text) from public, anon;

-- Public resolution (the /v/<code> page is for donors — no auth).
create or replace function public.resolve_video_link(p_code text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object('f', f, 'v', v)
  from video_links where code = lower(p_code);
$$;
grant execute on function public.resolve_video_link(text) to anon, authenticated;
