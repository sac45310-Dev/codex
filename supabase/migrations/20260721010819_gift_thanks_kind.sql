-- Gift → thank-you video loop (2026-07-22). The prep/approve/send flow
-- (prepared_messages + event_actions) was limited to key dates and child
-- birthdays; widen both kind checks so a gift thank-you can ride the same
-- rails: kind 'gift', ref_id = donations.id, occurrence_date = gift date.
-- Everything else (video storage path, approve-to-send, action upserts)
-- works unchanged.

alter table public.event_actions
  drop constraint if exists event_actions_kind_check;
alter table public.event_actions
  add constraint event_actions_kind_check
  check (kind in ('key_date', 'child_birthday', 'gift'));

alter table public.prepared_messages
  drop constraint if exists prepared_messages_kind_check;
alter table public.prepared_messages
  add constraint prepared_messages_kind_check
  check (kind in ('key_date', 'child_birthday', 'gift'));
