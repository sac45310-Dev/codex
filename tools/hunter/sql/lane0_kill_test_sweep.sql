-- Lane 0: mechanical kill-test sweep. Run before a wave; costs zero searches.
-- Applied 2026-09-07: rejected 123 of 367 unrostered orgs (34% of the queue).
--
-- These orgs matched reject patterns already documented in the kill test, so
-- dispatching agents at them would have burned roughly a third of the wave's
-- search budget rediscovering that they fail.
--
-- THE PROTECT-LIST IS THE IMPORTANT PART. A blank regex sweep destroys real
-- targets that happen to contain a junk word:
--   "Campus Outreach - University of Memphis"  matched \yuniversity\y
--   "ReachGlobal (Evangelical Free Church...)" matched \ychurch\y
--   "World Witness (Board of Foreign Missions of the ARP Church)" -- same
--   "Stadia (Church Planting)"                  -- same
--   "Mission Doctors Association"               matched \yassociation\y
-- All five are support-raising orgs -- Tier A sources, the most valuable kind.
-- Always eyeball the match list by bucket before running the mutation.

with junk as (
  select id, org_name, website,
    case
      when org_name ilike '%Evangelical Free Church of America%' then 'denomination'
      when coalesce(website,'') ilike '%usachurches.org%'
        or org_name ~* '\y(church|chapel|parish|cathedral|congregation)\y' then 'church_salaried'
      when org_name ~* '\y(publish|publisher|publishers|press|books)\y' then 'business_vendor'
      when org_name ~* '\y(seminary|college|university|school|academy)\y' then 'school_salaried'
      else 'too_institutional'
    end as reason_code
  from sales.hunt_targets
  where roster_status = 'unrostered'
    and (coalesce(website,'') ilike '%usachurches.org%'
         or org_name ~* '\y(church|chapel|parish|cathedral|congregation)\y'
         or org_name ~* '\y(publish|publisher|publishers|press|books)\y'
         or org_name ~* '\y(seminary|college|university|school|academy)\y'
         or org_name ~* '\y(conference|convention|society|association)\y')
    and org_name not ilike 'Campus Outreach%'
    and org_name not ilike 'ReachGlobal%'
    and org_name not ilike 'World Witness%'
    and org_name not ilike 'Stadia (Church Planting)%'
    and org_name not in ('Mission Doctors Association','Humane Society of South Coastal Georgia',
                         'Philadelphia Animal Welfare Society','Catholic Campus Ministry Association',
                         'Association for Global Health Professionals','Christian Basketball Association',
                         'World Association for Christian Communication')
),
neg as (
  insert into sales.hunt_negatives (entity_kind, name, website, reason_code, detail, source)
  select 'org', j.org_name, j.website, j.reason_code,
         'Lane 0 mechanical kill-test sweep: matched documented reject pattern; never dispatched.',
         'lane0:2026-09-07'
  from junk j
  where not exists (select 1 from sales.hunt_negatives n
                    where n.entity_kind='org' and lower(trim(n.name)) = lower(trim(j.org_name)))
  returning 1
),
upd as (
  update sales.hunt_targets t set roster_status='rejected', reject_reason=j.reason_code
  from junk j where t.id = j.id returning 1
)
select (select count(*) from neg) as negatives_added, (select count(*) from upd) as orgs_rejected;
