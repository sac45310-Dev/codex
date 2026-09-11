-- Post-import verification for sales.scout_candidates
select count(*) as total,
       count(*) filter (where fit_score >= 8) as fit8plus,
       count(*) filter (where fit_score between 6 and 7) as fit67
from sales.scout_candidates;

select fit_score, count(*) from sales.scout_candidates
group by fit_score order by fit_score desc nulls last;

-- Should return 0 rows worth of duplicates:
select count(*) as duplicate_names from (
  select lower(trim(org_name)) from sales.scout_candidates
  group by 1 having count(*) > 1
) d;

-- Should be 0 (status check constraint sanity):
select count(*) as bad_status from sales.scout_candidates
where status not in ('pending','approved','rejected','skipped');

select org_name, fit_score, website, created_at
from sales.scout_candidates order by created_at desc limit 5;
