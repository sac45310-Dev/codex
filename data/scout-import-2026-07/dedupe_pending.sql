-- Post-import cleanup for sales.scout_candidates.
--
-- The 2026-07 import batches that ran BEFORE the website-dedup upgrade used
-- name-only guards, so the review queue can contain the same person under
-- two name spellings sharing one URL (e.g. "Aaron & Stacy Jex" vs "Aaron and
-- Stacy Jex"). This collapses those without deleting anything: the lower-fit
-- member of each duplicate pair is marked 'skipped' (it drops out of the
-- pending review queue but stays in the table and can be un-skipped).
--
-- SAFETY:
--  * touches ONLY status='pending', lead_id is null rows — never anything a
--    human already reviewed or converted to a lead.
--  * frequency-limited to website groups of exactly 2 (name-variant pairs).
--    A URL shared by 3+ pending rows is a roster/platform page listing
--    distinct people and is left completely alone.
--  * reversible: un-skip with
--      update sales.scout_candidates set status='pending'
--      where review_note like '%[auto: website-duplicate%';
--
-- Idempotent: re-running skips nothing new once each group has one survivor.

with norm as (
  select id, fit_score, created_at,
         rtrim(lower(regexp_replace(website, '^https?://(www\.)?', '', 'i')), '/') as site
  from sales.scout_candidates
  where status = 'pending' and lead_id is null
    and website is not null and btrim(website) <> ''
),
pairs as (               -- only 2-member website groups (name-variant dupes)
  select site from norm group by site having count(*) = 2
),
ranked as (
  select n.id,
         row_number() over (
           partition by n.site
           order by n.fit_score desc nulls last, n.created_at asc, n.id asc
         ) as rk
  from norm n join pairs p on p.site = n.site
)
update sales.scout_candidates c
set status = 'skipped',
    review_note = trim(both ' ' from
      coalesce(c.review_note, '') || ' [auto: website-duplicate of higher-fit pending candidate]')
from ranked r
where c.id = r.id and r.rk > 1;

-- Report what was collapsed and confirm no pending website-dups remain:
select count(*) as marked_skipped
from sales.scout_candidates
where status = 'skipped'
  and review_note like '%[auto: website-duplicate%';

select count(*) as remaining_pending_website_dups from (
  select rtrim(lower(regexp_replace(website, '^https?://(www\.)?', '', 'i')), '/') as site
  from sales.scout_candidates
  where status = 'pending' and lead_id is null
    and website is not null and btrim(website) <> ''
  group by site having count(*) = 2
) d;
