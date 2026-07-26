-- Explicit onboarding flag instead of inferring from the fallback tenant name.
alter table public.tenants add column if not exists onboarded_at timestamptz;

-- Backfill: existing tenants that already have a real name are onboarded.
update public.tenants
   set onboarded_at = now()
 where onboarded_at is null
   and legal_name <> 'New Organization';

-- Signups that supply org_name (email/password form) are onboarded at once;
-- OAuth signups leave it null so the app shows the onboarding screen.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare new_tenant_id uuid;
begin
  insert into public.tenants (legal_name, onboarded_at)
  values (coalesce(new.raw_user_meta_data->>'org_name', 'New Organization'),
          case when new.raw_user_meta_data->>'org_name' is not null then now() end)
  returning id into new_tenant_id;

  insert into public.users (id, tenant_id, name, email, role)
  values (new.id, new_tenant_id,
          coalesce(new.raw_user_meta_data->>'full_name', new.email),
          new.email, 'admin');
  return new;
end $$;
