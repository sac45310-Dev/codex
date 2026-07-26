-- A donor has exactly one birthday / giving anniversary / ministry
-- anniversary; only 'custom' dates may repeat. UI enforces this too —
-- this index is the backstop.
create unique index if not exists key_dates_one_per_type
  on key_dates (donor_id, type)
  where type <> 'custom';
