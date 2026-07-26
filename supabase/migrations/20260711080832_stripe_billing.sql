alter table public.tenants
  add column stripe_customer_id text,
  add column stripe_subscription_id text,
  add column subscription_status text not null default 'none',
  add column plan text,
  add column current_period_end timestamptz;

create index tenants_stripe_customer_idx on public.tenants (stripe_customer_id);

-- Founder account: comped for life
update public.tenants
   set subscription_status = 'active', plan = 'founder'
 where legal_name = 'Drummond Family Enterprises';
