-- NOTE: the twilio_account_sid and twilio_auth_token values applied by this
-- migration have been REDACTED in the tracked copy. They are live credentials
-- and GitHub push protection (correctly) blocks committing them. The real
-- values remain in public.app_config in the database; set them there or via
-- the dashboard rather than in version control.
-- Server-only key/value config. RLS on with NO policies: anon/authenticated
-- can never read it; Edge Functions read it with the service role key.
create table public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;

insert into public.app_config (key, value) values
  ('twilio_account_sid', 'REDACTED_SEE_NOTE'),
  ('twilio_auth_token', 'REDACTED_SEE_NOTE'),
  ('twilio_from_number', '+15005550006'),
  ('twilio_webhook_url', 'https://leuhdxomjpoaiacxrwbz.supabase.co/functions/v1/twilio-inbound');
