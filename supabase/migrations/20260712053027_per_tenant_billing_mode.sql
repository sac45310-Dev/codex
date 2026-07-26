-- Per-tenant billing lane: 'live' tenants see live Stripe links/keys,
-- 'test' tenants stay in the sandbox forever (a permanent staging lane for
-- exercising subscribe/cancel/past-due against real production code).
alter table public.tenants
  add column billing_mode text not null default 'live'
    check (billing_mode in ('live','test'));

-- The founder org is the designated sandbox playground.
update public.tenants set billing_mode = 'test'
  where legal_name = 'Drummond Family Enterprises';
