-- ============ Two-way messaging inbox (BUILDLOG 2026-07-18) ================
-- Turns the per-donor message log into a real inbox: read state, live
-- updates (Supabase Realtime), and iOS push-token storage.

-- 1. Read state on inbound messages. ----------------------------------------
alter table public.messages add column read_at timestamptz;
create index messages_unread_idx on public.messages (tenant_id, donor_id)
  where direction = 'inbound' and read_at is null;

-- Mark a whole donor thread read (called when the thread opens). RLS-scoped
-- via the caller's tenant; any member may mark read (viewers included —
-- reading is not a write to donor data).
create or replace function public.mark_thread_read(p_donor_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth_tenant_id() is null then raise exception 'Not authorized'; end if;
  update messages set read_at = now()
    where tenant_id = auth_tenant_id()
      and donor_id = p_donor_id
      and direction = 'inbound'
      and read_at is null;
end $$;
revoke execute on function public.mark_thread_read(uuid) from public, anon;

-- 2. iOS push tokens (APNs). -------------------------------------------------
-- One row per device; a user can have several devices. Tokens are written
-- by the signed-in user for themselves; the send-push function (service
-- role) reads all tokens for a tenant's users.
create table public.push_tokens (
  token text primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  platform text not null default 'ios',
  updated_at timestamptz not null default now()
);
create index push_tokens_tenant_idx on public.push_tokens (tenant_id);
alter table public.push_tokens enable row level security;
create policy push_tokens_own on public.push_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid() and tenant_id = auth_tenant_id());
create trigger trg_push_tokens_tenant
  before insert on public.push_tokens
  for each row execute function set_tenant_id();

-- 3. Realtime: stream new messages to signed-in clients (RLS applies). ------
alter publication supabase_realtime add table public.messages;
