-- Email marketing add-on billing (BUILDLOG 2026-07-20 leftover). The addons
-- catalog row already existed with null Stripe prices ("soft-off until the
-- price is set"); this fills in the LIVE price (created 2026-07-20 on the
-- live account: $10/mo, prod_Uv6DQGXcZitLAO) and adds the per-tenant billing
-- state for the email-addon-billing edge fn, which adds/removes the
-- subscription line-item when a NON-Launch tenant toggles the add-on
-- (Launch includes it free — plan-granted orgs are never billed). Test lane
-- price stays null until one is created on the sandbox Stripe account →
-- that lane soft-offs.

update public.addons
   set stripe_price_monthly = 'price_1TvG1WLVblefTO2cLfxjJYAg',
       updated_at = now()
 where id = 'email_marketing' and stripe_price_monthly is null;

-- One row per tenant that currently carries the paid line-item.
create table public.email_addon_billing (
  tenant_id uuid primary key references public.tenants(id) on delete cascade,
  stripe_item_id text not null,
  updated_at timestamptz not null default now()
);
alter table public.email_addon_billing enable row level security;
-- No policies: service-role only (the edge fn); nothing client-visible here.
