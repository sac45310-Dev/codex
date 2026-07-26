-- ============ Donation pages (DONATIONS.md) ================================
-- Each org gets ONE public giving page at donorsend.app/<slug>. Payments run
-- on the ORG's own processor account (payment_connections, Stripe Connect
-- first — provider column keeps the door open for others). Gated by the
-- donations.page entitlement (paid tiers); manual gift entry stays free.

-- 1. Page content -----------------------------------------------------------
create table public.donation_pages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null unique references public.tenants(id) on delete cascade,
  slug text not null unique
    check (slug ~ '^[a-z0-9](?:-?[a-z0-9]){2,29}$'),
  headline text,
  story text,
  video_url text,
  logo_path text,
  photo_path text,
  suggested_amounts integer[] not null default '{25,50,100,250}',
  default_amount integer,
  allow_recurring boolean not null default true,
  thank_you_message text,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.donation_pages enable row level security;
create policy tenant_isolation on public.donation_pages
  for all using (tenant_id = auth_tenant_id());
create policy admin_only_ins on public.donation_pages as restrictive
  for insert with check (coalesce(tenant_role(), '') = 'admin');
create policy admin_only_upd on public.donation_pages as restrictive
  for update using (coalesce(tenant_role(), '') = 'admin');
create policy admin_only_del on public.donation_pages as restrictive
  for delete using (coalesce(tenant_role(), '') = 'admin');
create policy viewer_ro_ins on public.donation_pages as restrictive
  for insert with check (coalesce(tenant_role(), '') <> 'viewer');
create policy viewer_ro_upd on public.donation_pages as restrictive
  for update using (coalesce(tenant_role(), '') <> 'viewer');
create policy viewer_ro_del on public.donation_pages as restrictive
  for delete using (coalesce(tenant_role(), '') <> 'viewer');
create policy shadow_ro_ins on public.donation_pages as restrictive
  for insert with check (not shadow_write_blocked());
create policy shadow_ro_upd on public.donation_pages as restrictive
  for update using (not shadow_write_blocked());
create policy shadow_ro_del on public.donation_pages as restrictive
  for delete using (not shadow_write_blocked());
create policy suspended_ro_ins on public.donation_pages as restrictive
  for insert with check (tenant_not_suspended());
create policy suspended_ro_upd on public.donation_pages as restrictive
  for update using (tenant_not_suspended());
create policy suspended_ro_del on public.donation_pages as restrictive
  for delete using (tenant_not_suspended());

create trigger trg_donation_pages_tenant
  before insert on public.donation_pages
  for each row execute function set_tenant_id();

create or replace function public.donation_page_slug_guard()
returns trigger language plpgsql as $$
begin
  if new.slug = any (array[
    'admin','api','app','about','assets','blog','contact','dashboard',
    'docs','donate','donations','give','giving','help','home','index',
    'legal','login','logout','ministries','pay','preview','pricing',
    'privacy','settings','signin','signup','static','support','teams',
    'terms','test','v','www'
  ]) then
    raise exception 'That link name is reserved — please pick another.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger trg_donation_pages_slug
  before insert or update of slug on public.donation_pages
  for each row execute function donation_page_slug_guard();

create or replace function public.enforce_donation_page_flag()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_tenant uuid;
begin
  v_tenant := coalesce(new.tenant_id, auth_tenant_id());
  if v_tenant is null then return new; end if;
  if not coalesce(tenant_flag(v_tenant, 'donations.page'), false) then
    raise exception 'Donation pages are available on paid plans — upgrade to publish yours.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger trg_donation_pages_entitlement
  before insert on public.donation_pages
  for each row execute function enforce_donation_page_flag();

-- 2. Payment connections ----------------------------------------------------
create table public.payment_connections (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  provider text not null default 'stripe' check (provider in ('stripe')),
  account_id text,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'disconnected')),
  livemode boolean not null default true,
  connected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, provider)
);

alter table public.payment_connections enable row level security;
create policy tenant_read on public.payment_connections
  for select using (tenant_id = auth_tenant_id());

create trigger trg_payment_connections_tenant
  before insert on public.payment_connections
  for each row execute function set_tenant_id();

-- 3. Public page payload ----------------------------------------------------
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
    'default_amount', p.default_amount,
    'allow_recurring', p.allow_recurring,
    'org_name', t.legal_name,
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
grant execute on function public.get_donation_page(text) to anon, authenticated;

-- 4. Slug availability ------------------------------------------------------
create or replace function public.slug_available(p_slug text)
returns boolean language plpgsql stable security definer set search_path to 'public' as $$
begin
  if auth_tenant_id() is null then raise exception 'Not authorized'; end if;
  return not exists (
    select 1 from donation_pages
    where slug = lower(p_slug) and tenant_id <> auth_tenant_id()
  );
end $$;
revoke execute on function public.slug_available(text) from public, anon;

-- 5. Page media bucket ------------------------------------------------------
insert into storage.buckets (id, name, public) values
  ('donation-pages', 'donation-pages', true)
on conflict (id) do nothing;
create policy "donation pages public read" on storage.objects
  for select using (bucket_id = 'donation-pages');
create policy "donation pages tenant insert" on storage.objects
  for insert with check (bucket_id = 'donation-pages'
    and (storage.foldername(name))[1] = (auth_tenant_id())::text);
create policy "donation pages tenant update" on storage.objects
  for update using (bucket_id = 'donation-pages'
    and (storage.foldername(name))[1] = (auth_tenant_id())::text);
create policy "donation pages tenant delete" on storage.objects
  for delete using (bucket_id = 'donation-pages'
    and (storage.foldername(name))[1] = (auth_tenant_id())::text);
