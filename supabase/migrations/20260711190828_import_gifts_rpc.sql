-- Transactional gift import: match existing donors (email → phone → name),
-- create missing ones (visible to later rows in the same run), skip duplicate
-- gifts, and insert. All in one transaction so a mid-import failure rolls the
-- whole thing back instead of leaving orphan donors / half-imported gifts.
-- Rows arrive already parsed/normalized by the client (csv.js).
create or replace function public.import_gifts(
  p_rows jsonb,
  p_create_donors boolean default true,
  p_skip_duplicates boolean default true,
  p_mark_thanked boolean default false
) returns jsonb
language plpgsql
security invoker
set search_path to 'public'
as $$
declare
  v_tenant uuid := auth_tenant_id();
  v_uid uuid := auth.uid();
  v_now timestamptz := now();
  r jsonb;
  v_email text;
  v_phone text;
  v_first text;
  v_last text;
  v_namekey text;
  v_donor_id uuid;
  v_amount numeric;
  v_date date;
  v_imported int := 0;
  v_created int := 0;
  v_dupes int := 0;
  v_unmatched int := 0;
begin
  if v_tenant is null then
    raise exception 'no tenant for current user';
  end if;

  for r in select value from jsonb_array_elements(p_rows) as t(value)
  loop
    v_email   := nullif(lower(trim(coalesce(r->>'email', ''))), '');
    v_phone   := nullif(trim(coalesce(r->>'phone', '')), '');
    v_first   := nullif(trim(coalesce(r->>'first', '')), '');
    v_last    := nullif(trim(coalesce(r->>'last', '')), '');
    v_namekey := nullif(lower(trim(concat_ws(' ', v_first, v_last))), '');
    v_amount  := (r->>'amount')::numeric;
    v_date    := (r->>'date')::date;

    -- Match on email, then phone, then full name. A donor created earlier in
    -- THIS loop is already in the table, so a later row for the same person
    -- resolves to it. Oldest match wins (deterministic on same-name donors).
    v_donor_id := null;
    if v_email is not null then
      select id into v_donor_id from donors
        where tenant_id = v_tenant and lower(email) = v_email
        order by created_at asc limit 1;
    end if;
    if v_donor_id is null and v_phone is not null then
      select id into v_donor_id from donors
        where tenant_id = v_tenant and phone_e164 = v_phone
        order by created_at asc limit 1;
    end if;
    if v_donor_id is null and v_namekey is not null then
      select id into v_donor_id from donors
        where tenant_id = v_tenant
          and lower(trim(concat_ws(' ', first_name, last_name))) = v_namekey
        order by created_at asc limit 1;
    end if;

    if v_donor_id is null then
      if not p_create_donors
         or (v_email is null and v_phone is null and v_namekey is null) then
        v_unmatched := v_unmatched + 1;
        continue;
      end if;
      -- tenant_id is filled by the set_tenant_id trigger.
      insert into donors (first_name, last_name, email, phone_e164, source, created_by)
      values (
        coalesce(v_first, split_part(v_email, '@', 1), 'Unknown'),
        v_last,
        nullif(r->>'email', ''),
        v_phone,
        'gift_import',
        v_uid
      )
      returning id into v_donor_id;
      v_created := v_created + 1;
    end if;

    if p_skip_duplicates and exists (
      select 1 from donations
      where donor_id = v_donor_id and date = v_date and amount = v_amount
    ) then
      v_dupes := v_dupes + 1;
      continue;
    end if;

    insert into donations
      (donor_id, amount, date, method, fund, note, created_by, thanked, thanked_at, thanked_by)
    values (
      v_donor_id, v_amount, v_date,
      nullif(r->>'method', ''), nullif(r->>'fund', ''), nullif(r->>'note', ''),
      v_uid, p_mark_thanked,
      case when p_mark_thanked then v_now else null end,
      case when p_mark_thanked then v_uid else null end
    );
    v_imported := v_imported + 1;
  end loop;

  return jsonb_build_object(
    'imported', v_imported,
    'donorsCreated', v_created,
    'skippedDuplicates', v_dupes,
    'skippedUnmatched', v_unmatched
  );
end $$;

grant execute on function public.import_gifts(jsonb, boolean, boolean, boolean) to authenticated;
