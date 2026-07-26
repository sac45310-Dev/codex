-- Email & content studio (#1). Editable copy for the lifecycle emails,
-- out of code and into the DB. Edge fns read these with a code fallback;
-- staff edit them in /admin. Seeded to match the current code copy so
-- turning this on changes nothing until edited.
create table public.email_templates (
  key text primary key,
  label text not null,
  subject text not null,
  heading text not null,
  body_html text not null,          -- supports {org} and {first_name}
  cta_label text,
  cta_path text,                    -- app-relative, e.g. /donors
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.email_templates enable row level security; -- staff RPC only

insert into public.email_templates (key, label, subject, heading, body_html, cta_label, cta_path) values
('lifecycle_welcome', 'Welcome (on signup)', 'Welcome to DonorSend',
 'Your donors are people, not a list.',
 '<p>Welcome! Here''s the fastest path to your first "wow": add one supporter, record a 20-second video, and text it from your own phone.</p><p>Most people feel the difference on the very first send.</p>',
 'Add your first donor', '/donors'),
('lifecycle_nudge_no_donors', 'Day-3 nudge (no donors yet)', 'Add your first supporter (2 minutes)',
 'Ready when you are.',
 '<p>You set up {org} but haven''t added a supporter yet. It takes about two minutes, and you can import a whole list from a spreadsheet if that''s easier.</p><p>Once someone''s in, DonorSend remembers their birthday and nudges you to say thanks — so no one slips through the cracks.</p>',
 'Add or import donors', '/donors'),
('lifecycle_trial_ending', 'Trial ending', 'Your DonorSend trial ends soon',
 'Keep your momentum going.',
 '<p>Your trial is wrapping up in the next couple of days. If DonorSend is helping you stay close to your supporters, you don''t have to do anything — your plan continues automatically.</p><p>Want to change tiers first? You can compare plans anytime.</p>',
 'Review your plan', '/settings/billing'),
('lifecycle_winback', 'Win-back (after cancel)', 'We saved everything for you',
 'Your donors and history are still here.',
 '<p>You moved {org} back to the Free plan — no problem, and nothing was deleted. Your supporters, notes, and gift history are exactly where you left them.</p><p>If there''s something DonorSend was missing for you, just reply to this email — a real person reads it.</p>',
 'Open DonorSend', '/');

-- Staff read + edit via guarded RPCs.
create or replace function public.admin_list_email_templates()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(),'') not in ('owner','support','billing') then
    raise exception 'Not authorized';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(t) order by t.key) from email_templates t), '[]'::jsonb);
end $$;

create or replace function public.admin_save_email_template(
  p_key text, p_subject text, p_heading text, p_body_html text,
  p_cta_label text, p_cta_path text, p_enabled boolean)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(platform_role(),'') not in ('owner','support') then
    raise exception 'Not authorized';
  end if;
  update email_templates set
    subject = p_subject, heading = p_heading, body_html = p_body_html,
    cta_label = p_cta_label, cta_path = p_cta_path, enabled = p_enabled,
    updated_at = now(), updated_by = auth.uid()
  where key = p_key;
  if not found then raise exception 'Unknown template'; end if;
end $$;
