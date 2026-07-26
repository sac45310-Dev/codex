-- Donor headshots + social profiles
alter table public.donors
  add column photo_url text,
  add column facebook_url text,
  add column instagram_url text,
  add column tiktok_url text,
  add column linkedin_url text;

-- Per-user dashboard planning window:
-- 'next_month' (default) | 'days:N' | 'range:YYYY-MM-DD:YYYY-MM-DD'
alter table public.users
  add column dashboard_window text not null default 'next_month';

-- Storage bucket for donor photos: public read, tenant-scoped writes
-- (object paths are <tenant_id>/<donor_id>.jpg)
insert into storage.buckets (id, name, public)
values ('donor-photos', 'donor-photos', true)
on conflict (id) do nothing;

create policy "donor photos public read" on storage.objects
  for select to public using (bucket_id = 'donor-photos');
create policy "donor photos tenant insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'donor-photos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
create policy "donor photos tenant update" on storage.objects
  for update to authenticated
  using (bucket_id = 'donor-photos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
create policy "donor photos tenant delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'donor-photos'
    and (storage.foldername(name))[1] = auth_tenant_id()::text);
