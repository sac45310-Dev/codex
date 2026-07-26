alter table public.tenants
  add column address_line1 text,
  add column address_line2 text,
  add column city text,
  add column state text,
  add column postal_code text;
