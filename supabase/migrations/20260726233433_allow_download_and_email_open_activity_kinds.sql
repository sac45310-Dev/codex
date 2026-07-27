-- sales.activities.kind was constrained to the pre-web-tracking set, so the
-- new per-lead tracking could not file a download or an email open. Widening
-- a CHECK is additive: every existing row still satisfies it.
--
-- 'download'   - a distinct buying signal, deliberately NOT folded into
--                'visit' so it can be filtered and surfaced on its own.
-- 'email_open' - written only when the (optional) open-tracking pixel is on.
alter table sales.activities drop constraint activities_kind_check;
alter table sales.activities add constraint activities_kind_check
  check (kind = any (array[
    'call','email_out','email_in','note','task','meeting','text',
    'visit','download','email_open'
  ]));
