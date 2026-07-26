-- Remember which storage video (if any) a logged message carried, so the donor
-- profile can offer a "Watch video" link — valid until the weekly video-cleanup
-- cron purges the file from storage.
alter table public.messages
  add column if not exists video_path text;
