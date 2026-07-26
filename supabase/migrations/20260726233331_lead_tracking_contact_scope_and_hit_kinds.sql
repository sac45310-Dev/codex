-- Per-lead web tracking, part 1 (database layer).
--
-- sales.links / sales.link_hits already existed but were never wired up
-- (0 rows): sales_create_link could mint a link and sales_track_visit could
-- record a hit, but nothing served the redirect, so no click ever landed.
-- This adds what per-CONTACT tracking needs, ahead of the /r/<token> endpoint.

-- 1. Target a specific person, not just the org.
alter table sales.links     add column if not exists contact_id uuid
  references sales.contacts(id) on delete set null;
alter table sales.link_hits add column if not exists contact_id uuid;

-- 2. Room for user-agent family, hit kind, coarse geo. No raw IPs, ever.
alter table sales.link_hits add column if not exists meta jsonb not null default '{}'::jsonb;

create index if not exists links_contact_idx     on sales.links(contact_id);
create index if not exists link_hits_contact_idx on sales.link_hits(contact_id, created_at desc);
create index if not exists link_hits_link_idx    on sales.link_hits(link_id, created_at desc);

-- 3. Strengthen the token. It identifies a person, so 48 bits (md5 truncated
--    to 12 hex) was thin. 32 hex chars from a v4 uuid is ~122 bits. Safe to
--    change now: sales.links is empty, and existing tokens would still work.
alter table sales.links alter column token set default replace(gen_random_uuid()::text, '-', '');

-- 4. sales_create_link: accept an optional contact_id, verified to belong to
--    the same lead so a link can't be minted against someone else's contact.
create or replace function public.sales_create_link(p json)
returns json language plpgsql security definer set search_path = public, sales as $$
declare v_row sales.links; v_contact uuid;
begin
  if coalesce(platform_role(),'') = '' then raise exception 'Not authorized'; end if;
  v_contact := nullif(p->>'contact_id','')::uuid;
  if v_contact is not null and not exists (
       select 1 from sales.contacts c
        where c.id = v_contact and c.lead_id = (p->>'lead_id')::uuid) then
    raise exception 'contact does not belong to this lead';
  end if;
  insert into sales.links (lead_id, contact_id, label, dest, created_by)
  values (
    (p->>'lead_id')::uuid,
    v_contact,
    nullif(trim(coalesce(p->>'label','')), ''),
    -- dest is a path on donorsend.app, never a full URL (no open redirect).
    case when coalesce(p->>'dest','') ~ '^/[a-zA-Z0-9_/.-]*$' then p->>'dest' else '/' end,
    auth.jwt()->>'email')
  returning * into v_row;
  return row_to_json(v_row);
end $$;

-- 5. sales_track_visit: unchanged contract for existing callers (token, path,
--    referrer), plus optional kind + ua. Still anon-callable: it is the public
--    ingest for page views, and is token-gated and rate-limited.
create or replace function public.sales_track_visit(p json)
returns void language plpgsql security definer set search_path = public, sales as $$
declare
  v_link     sales.links;
  v_kind     text;
  v_act_kind text;
  v_subject  text;
begin
  select * into v_link from sales.links where token = p->>'token';
  if not found then return; end if;

  v_kind := lower(coalesce(nullif(trim(p->>'kind'),''), 'page'));
  if v_kind not in ('page','click','download','email_open') then v_kind := 'page'; end if;

  -- Rate limit is per link, across all hit kinds.
  if (select count(*) from sales.link_hits
      where link_id = v_link.id
        and created_at > now() - interval '1 hour') >= 120 then
    return;
  end if;

  insert into sales.link_hits (link_id, lead_id, contact_id, path, referrer, meta)
  values (v_link.id, v_link.lead_id, v_link.contact_id,
          left(p->>'path', 300), left(p->>'referrer', 300),
          jsonb_strip_nulls(jsonb_build_object(
            'kind', v_kind,
            -- family/OS only; the full UA string is a fingerprinting surface.
            'ua',      left(nullif(trim(coalesce(p->>'ua','')), ''), 120),
            'country', left(nullif(trim(coalesce(p->>'country','')), ''), 2))));

  update sales.links
     set hit_count = hit_count + 1, last_hit_at = now()
   where id = v_link.id;

  v_act_kind := case v_kind when 'download' then 'download'
                            when 'email_open' then 'email_open'
                            else 'visit' end;
  v_subject  := case v_kind when 'download'   then 'Downloaded a file'
                            when 'email_open' then 'Opened an email'
                            when 'click'      then 'Clicked a tracked link'
                            else 'Visited the site' end;

  -- One timeline entry per link per kind per 6h -- a browsing session reads as
  -- a single visit, not a row per page. Downloads always log: each one is a
  -- distinct buying signal, not session noise. Does NOT bump leads.updated_at:
  -- the stale list tracks OUR touches, and a hot visitor going "stale" is
  -- exactly the nudge.
  if v_kind = 'download'
     or not exists (select 1 from sales.activities
                     where lead_id = v_link.lead_id and kind = v_act_kind
                       and meta->>'link_id' = v_link.id::text
                       and created_at > now() - interval '6 hours') then
    insert into sales.activities (lead_id, contact_id, kind, subject, body, meta)
    values (v_link.lead_id, v_link.contact_id, v_act_kind, v_subject,
            coalesce(v_link.label, v_link.dest),
            jsonb_build_object('link_id', v_link.id, 'kind', v_kind,
                               'path', left(p->>'path', 300)));
  end if;
end $$;

-- 6. sales_link_resolve: what /r/<token> calls. Records the click and hands
--    back the destination path in one round trip. service_role only -- the
--    edge function holds that key; anon must never enumerate tokens.
create or replace function public.sales_link_resolve(p json)
returns json language plpgsql security definer set search_path = public, sales as $$
declare v_link sales.links;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'Not authorized';
  end if;
  select * into v_link from sales.links where token = p->>'token';
  if not found then
    return json_build_object('ok', false);
  end if;
  perform public.sales_track_visit(json_build_object(
    'token', p->>'token', 'kind', 'click',
    'path', v_link.dest, 'referrer', p->>'referrer',
    'ua', p->>'ua', 'country', p->>'country'));
  return json_build_object('ok', true, 'dest', v_link.dest,
                           'lead_id', v_link.lead_id, 'contact_id', v_link.contact_id);
end $$;

revoke execute on function public.sales_link_resolve(json) from public, anon, authenticated;
grant  execute on function public.sales_link_resolve(json) to service_role;
