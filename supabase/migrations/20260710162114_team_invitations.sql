create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  email text not null,
  role user_role not null default 'sender',
  token uuid not null default gen_random_uuid() unique,
  invited_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

alter table public.invitations enable row level security;

create policy tenant_isolation on public.invitations
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());

create index invitations_tenant_idx on public.invitations (tenant_id);
create index invitations_invited_by_idx on public.invitations (invited_by);

create trigger trg_invitations_tenant
  before insert on public.invitations
  for each row execute function set_tenant_id();

-- Moves the calling user into the inviting tenant. SECURITY DEFINER because
-- the caller cannot see the invitation row (other tenant) under RLS.
create or replace function public.accept_invitation(p_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
  user_email text;
  old_tenant uuid;
begin
  select email into user_email from auth.users where id = auth.uid();
  if user_email is null then
    raise exception 'Not signed in';
  end if;

  select * into inv from invitations
   where token = p_token and accepted_at is null;
  if inv is null then
    raise exception 'Invitation not found or already used';
  end if;
  if lower(inv.email) <> lower(user_email) then
    raise exception 'This invitation was sent to a different email address';
  end if;

  select tenant_id into old_tenant from users where id = auth.uid();

  update users set tenant_id = inv.tenant_id, role = inv.role
   where id = auth.uid();
  update invitations set accepted_at = now() where id = inv.id;

  -- Drop the signup-created tenant if joining left it empty.
  if old_tenant is not null and old_tenant <> inv.tenant_id
     and not exists (select 1 from users where tenant_id = old_tenant) then
    delete from tenants where id = old_tenant;
  end if;
end $$;

revoke execute on function public.accept_invitation(uuid) from anon, public;
