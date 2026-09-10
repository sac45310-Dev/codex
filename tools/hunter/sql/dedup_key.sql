-- The identity test a wave insert should use, and why it changed.
--
-- WAS: NOT EXISTS (... WHERE lower(trim(z.org_name)) = lower(trim(new.name)))
--
-- A global name match. Three problems, in increasing order of cost:
--
--   1. It loses real people. Two different "John Smith" at two different
--      agencies are one key, so the second is dropped. Measured today the rate
--      is low (6 repeated first+last pairs, 0 surviving cross-org collisions),
--      but it is unbounded: collision probability grows with table size, and
--      we are adding hundreds of common Anglo surnames per wave.
--
--   2. It fails SILENTLY. The insert reports rows loaded, never rows skipped,
--      so a false skip is indistinguishable from a name that was never found.
--      Wave w2026-09-09d reported "303 found / 297 loaded" and the 6-row gap
--      had to be reconstructed by hand.
--
--   3. It ignores the strongest identifier we hold. A personal giving URL
--      identifies a person far better than their name does.
--
-- NOW: identity is (normalized source_url, normalized name).
--   * same url + same name  -> duplicate, skip
--   * same url + diff name  -> a couple sharing a page, KEEP both
--   * diff url + same name  -> different person, or the same person found at a
--                              better citation, KEEP and let review decide
--   * no url                -> fall back to name, but only within the same
--                              target_org, so the key is scoped not global
--
-- Use sales.f_wave_dupe_check() below rather than hand-rolling NOT EXISTS.

create or replace function sales.norm_url(u text) returns text
language sql immutable as $$
  select case when u is null or u !~ '^https?://' then null
         else lower(regexp_replace(regexp_replace(u,'^https?://(www\.)?',''),'/+$','')) end;
$$;

create or replace function sales.norm_name(n text) returns text
language sql immutable as $$
  select nullif(lower(regexp_replace(trim(coalesce(n,'')), '\s+', ' ', 'g')), '');
$$;

-- Returns one row per candidate with a verdict, so a wave can report what it
-- skipped instead of quietly dropping it.
create or replace function sales.f_wave_dupe_check(
  cand jsonb  -- [{"name":..., "url":..., "org":...}, ...]
) returns table (name text, url text, org text, verdict text, matched_id uuid)
language sql stable as $$
  with x as (
    select e->>'name' as name, e->>'url' as url, e->>'org' as org,
           sales.norm_url(e->>'url') as nurl, sales.norm_name(e->>'name') as nname
    from jsonb_array_elements(cand) e)
  select x.name, x.url, x.org,
    case
      when m_url.id is not null then 'duplicate: same person at same url'
      when m_org.id is not null then 'duplicate: same name within same org'
      when m_any.id is not null then 'review: name seen elsewhere, different url'
      else 'new'
    end,
    coalesce(m_url.id, m_org.id, m_any.id)
  from x
  left join lateral (
    select c.id from sales.scout_candidates c
    where sales.norm_name(c.org_name) = x.nname
      and x.nurl is not null and sales.norm_url(c.source_url) = x.nurl
    limit 1) m_url on true
  left join lateral (
    select c.id from sales.scout_candidates c
    where sales.norm_name(c.org_name) = x.nname
      and sales.norm_name(c.meta->>'target_org') = sales.norm_name(x.org)
    limit 1) m_org on true
  left join lateral (
    select c.id from sales.scout_candidates c
    where sales.norm_name(c.org_name) = x.nname
    limit 1) m_any on true;
$$;

-- ---------------------------------------------------------------------------
-- Exclusion tokens, corrected 2026-09-10.
--
-- First cut took the last whitespace-delimited token of org_name as the
-- surname. For legacy "Name (Agency)" rows that yields "(bimi)" -- so all 16
-- BIMI records collapsed to a single useless token, and the domains that most
-- needed exclusions got none. Strip the parenthetical first, require the result
-- to look like a name, and raise the cap to 60.
--
-- Even at 60 the cap binds on the biggest domains: resonateglobalmission.org
-- holds 131 people, so exclusions cover 46% of them. Exclusion paging is a tool
-- for domains we have PARTIALLY mined, not a way to re-open one already worked
-- to exhaustion.
-- ---------------------------------------------------------------------------
create or replace view sales.v_hunt_domain_exclusions as
with cleaned as (
  select c.id,
    lower(regexp_replace(regexp_replace(c.source_url,'^https?://(www\.)?',''),'/.*$','')) domain,
    trim(regexp_replace(c.org_name, '\s*\([^()]*\)\s*$', '')) nm
  from sales.scout_candidates c
  where c.source_url ~ '^https?://'),
s as (
  select id, domain,
    lower(split_part(nm,' ', array_length(string_to_array(nm,' '),1))) surname
  from cleaned where nm ~ ' ')
select domain, count(distinct id) people_held,
       (array_agg(distinct surname))[1:60] as exclude_tokens
from s
where surname ~ '^[a-z][a-z''-]{2,}$'
group by 1;
