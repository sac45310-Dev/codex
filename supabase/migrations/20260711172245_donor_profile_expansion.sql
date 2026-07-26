-- A–K field expansion + gender/t-shirt (2026-07 product decision).
alter table public.donors
  add column preferred_name text,
  add column gender text check (gender in ('male','female')),
  add column tshirt_size text,
  add column donor_type text not null default 'individual'
    check (donor_type in ('individual','church','business','foundation')),
  add column church_name text,
  add column employer text,
  add column address_line1 text,
  add column address_line2 text,
  add column city text,
  add column state text,
  add column postal_code text,
  add column pledge_amount numeric check (pledge_amount is null or pledge_amount > 0),
  add column pledge_frequency text
    check (pledge_frequency in ('monthly','quarterly','annually')),
  add column pledge_start_date date,
  add column status text not null default 'active'
    check (status in ('active','archived','deceased')),
  add column assigned_to uuid references public.users(id) on delete set null,
  add column source text,
  add column referred_by uuid references public.donors(id) on delete set null;

-- Acknowledgment tracking: has this gift been thanked yet?
alter table public.donations
  add column thanked boolean not null default false;

-- Per-donor giving rollup for computed giving status (new/active/lapsed).
-- security_invoker so the underlying donations RLS applies to the caller.
create or replace view public.donor_giving_rollup
  with (security_invoker = true) as
select donor_id,
       min(date) as first_gift,
       max(date) as last_gift,
       count(*)  as gift_count
from public.donations
group by donor_id;
