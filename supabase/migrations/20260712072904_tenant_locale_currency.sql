-- Region formatting (dates/phones) and display currency are separate
-- settings: a missionary in Manila may keep USD giving.
alter table public.tenants
  add column locale text not null default 'en-US',
  add column currency text not null default 'USD' check (char_length(currency) = 3);
