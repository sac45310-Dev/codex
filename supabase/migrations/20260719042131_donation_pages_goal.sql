-- Campaign goal bar (DONATIONS.md v3): opt-in — the raised total is only
-- exposed publicly when the org sets a goal.
alter table public.donation_pages add column goal_amount integer;

create or replace function public.get_donation_page(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'slug', p.slug,
    'headline', p.headline,
    'story', p.story,
    'video_url', p.video_url,
    'logo_path', p.logo_path,
    'photo_path', p.photo_path,
    'suggested_amounts', to_jsonb(p.suggested_amounts),
    'amount_labels', to_jsonb(p.amount_labels),
    'monthly_amounts', to_jsonb(p.monthly_amounts),
    'default_amount', p.default_amount,
    'allow_recurring', p.allow_recurring,
    'thank_you_message', p.thank_you_message,
    'funds', to_jsonb(p.funds),
    'goal_amount', p.goal_amount,
    'raised', case when p.goal_amount is not null then (
      select coalesce(sum(d.amount), 0)::numeric
      from donations d
      where d.tenant_id = p.tenant_id and d.provider = 'stripe'
        and d.method = 'online'
    ) end,
    'org_name', t.legal_name,
    'ein', t.ein,
    'can_donate', exists (
      select 1 from payment_connections pc
      where pc.tenant_id = p.tenant_id
        and pc.provider = 'stripe' and pc.status = 'active'
    )
  )
  from donation_pages p
  join tenants t on t.id = p.tenant_id
  where p.slug = lower(p_slug) and p.published
    and t.suspended_at is null;
$$;
