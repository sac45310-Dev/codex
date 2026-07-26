-- When a tenant is deleted, cascaded donor/donation/message deletes fire
-- log_activity after the tenants row is already gone — the log insert then
-- violates the FK. Skip logging when the tenant no longer exists.
create or replace function public.log_activity()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
declare
  v_tenant uuid;
  v_actor uuid := auth.uid();
  v_action text;
  v_detail text;
  v_donor uuid;
  v_name text;
begin
  if tg_table_name = 'donors' then
    if tg_op = 'DELETE' then
      v_tenant := old.tenant_id;
      v_action := 'donor_deleted';
      v_detail := nullif(trim(coalesce(old.first_name,'') || ' ' || coalesce(old.last_name,'')), '');
    else
      v_tenant := new.tenant_id;
      v_donor := new.id;
      v_detail := nullif(trim(coalesce(new.first_name,'') || ' ' || coalesce(new.last_name,'')), '');
      if tg_op = 'INSERT' then
        v_action := 'donor_added';
      elsif new.status is distinct from old.status then
        v_action := case new.status
          when 'archived' then 'donor_archived'
          when 'deceased' then 'donor_deceased'
          else 'donor_restored' end;
      elsif new.consent_status is distinct from old.consent_status
         or new.photo_url is distinct from old.photo_url then
        return null;
      else
        v_action := 'donor_updated';
      end if;
    end if;

  elsif tg_table_name = 'donations' then
    select nullif(trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')), '')
      into v_name from donors where id = coalesce(new.donor_id, old.donor_id);
    if tg_op = 'DELETE' then
      v_tenant := old.tenant_id;
      v_donor := old.donor_id;
      v_action := 'gift_deleted';
      v_detail := '$' || old.amount || coalesce(' from ' || v_name, '');
    else
      v_tenant := new.tenant_id;
      v_donor := new.donor_id;
      v_detail := '$' || new.amount || coalesce(' from ' || v_name, '');
      if tg_op = 'INSERT' then
        v_action := 'gift_recorded';
      elsif new.thanked is distinct from old.thanked then
        v_action := case when new.thanked then 'gift_thanked' else 'gift_unthanked' end;
        v_actor := coalesce(new.thanked_by, v_actor);
      else
        v_action := 'gift_updated';
      end if;
    end if;

  elsif tg_table_name = 'messages' then
    v_tenant := new.tenant_id;
    v_donor := new.donor_id;
    select nullif(trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')), '')
      into v_name from donors where id = new.donor_id;
    if new.direction = 'outbound' then
      v_action := case when new.status = 'logged' then 'text_logged' else 'text_sent' end;
      v_actor := coalesce(new.sent_by, v_actor);
    else
      v_action := 'text_received';
      v_actor := null;
    end if;
    v_detail := v_name;

  elsif tg_table_name = 'donor_notes' then
    v_tenant := new.tenant_id;
    v_donor := new.donor_id;
    v_actor := coalesce(new.author_user_id, v_actor);
    select nullif(trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')), '')
      into v_name from donors where id = new.donor_id;
    v_action := 'note_added';
    v_detail := v_name;
  end if;

  if v_tenant is not null and v_action is not null
     and exists (select 1 from tenants where id = v_tenant) then
    insert into activity_log (tenant_id, actor_user_id, action, donor_id, detail)
    values (v_tenant, v_actor, v_action, v_donor, v_detail);
  end if;
  return null;
end;
$$;
