-- A message prepared ahead of an event: text and/or a recorded video,
-- saved as a draft and sent manually on the day.
create table public.prepared_messages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  donor_id uuid not null references public.donors(id) on delete cascade,
  kind text not null check (kind in ('key_date', 'child_birthday')),
  ref_id uuid not null,
  occurrence_date date not null,
  body text,
  video_path text,
  status text not null default 'draft' check (status in ('draft', 'sent')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (kind, ref_id, occurrence_date)
);
alter table public.prepared_messages enable row level security;
create policy tenant_isolation on public.prepared_messages
  for all using (tenant_id = auth_tenant_id())
  with check (tenant_id = auth_tenant_id());
create index prepared_messages_tenant_idx on public.prepared_messages (tenant_id);
create index prepared_messages_donor_idx on public.prepared_messages (donor_id);
create index prepared_messages_created_by_idx on public.prepared_messages (created_by);
create trigger trg_prepared_messages_tenant
  before insert on public.prepared_messages
  for each row execute function set_tenant_id();

-- Video messages bucket (tenant-scoped writes, public playback links)
insert into storage.buckets (id, name, public)
values ('donor-videos', 'donor-videos', true)
on conflict (id) do nothing;

create policy "donor videos public read" on storage.objects
  for select to public using (bucket_id = 'donor-videos');
create policy "donor videos tenant insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'donor-videos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
create policy "donor videos tenant update" on storage.objects
  for update to authenticated
  using (bucket_id = 'donor-videos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
create policy "donor videos tenant delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'donor-videos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
