-- Stripe price ids for the tier catalog, both lanes (BILLING.md Phase 2).
-- Test-lane ids get their own columns (tenants with billing_mode='test'
-- check out against the sandbox account forever).
alter table public.plans
  add column stripe_price_monthly_test text,
  add column stripe_price_annual_test text;

-- New tiers have no subscribers yet — plain updates pass the plan-edit guard.
update plans set
  stripe_price_monthly      = 'price_1TubTULVblefTO2cMyfs5nk7',
  stripe_price_annual       = 'price_1TubTVLVblefTO2cCZiTlc2a',
  stripe_price_monthly_test = 'price_1TubOqLCtmBOcsrVDpCHHuCZ',
  stripe_price_annual_test  = 'price_1TubOqLCtmBOcsrVo9aDVpYC'
  where id = 'startup_v1';
update plans set
  stripe_price_monthly      = 'price_1TubTWLVblefTO2cgqL0puIk',
  stripe_price_annual       = 'price_1TubTWLVblefTO2cnsoIStdE',
  stripe_price_monthly_test = 'price_1TubOrLCtmBOcsrVMZ35eylZ',
  stripe_price_annual_test  = 'price_1TubOsLCtmBOcsrV9rqCc0Hj'
  where id = 'growth_v1';
update plans set
  stripe_price_monthly      = 'price_1TubTXLVblefTO2clBNnG3B1',
  stripe_price_annual       = 'price_1TubTXLVblefTO2cXqSOAQBb',
  stripe_price_monthly_test = 'price_1TubOsLCtmBOcsrViwVtH9fD',
  stripe_price_annual_test  = 'price_1TubOtLCtmBOcsrV3eym6SXQ'
  where id = 'launch_v1';

-- legacy_29_v1 has live subscribers: the guard blocks in-place edits, and
-- rightly so. This is the documented deliberate use of the escape hatch —
-- we're recording the ORIGINAL $29 price ids (metadata backfill, not a
-- change to what anyone pays; Stripe prices are immutable anyway).
select set_config('app.allow_plan_edit', 'on', true);
update plans set
  stripe_price_monthly      = 'price_1TsA1RLVblefTO2cNG3Td02r',
  stripe_price_annual       = 'price_1TsA1QLVblefTO2cpdqkC4ym',
  stripe_price_monthly_test = 'price_1Trvv5LCtmBOcsrVIMaM1OKW',
  stripe_price_annual_test  = 'price_1TrvvILCtmBOcsrVBeHR1GQ3'
  where id = 'legacy_29_v1';
select set_config('app.allow_plan_edit', '', true);
