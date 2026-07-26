alter function public.us_timezone(text)      set search_path = pg_catalog;
alter function sales.norm_org_type(text)     set search_path = pg_catalog;
alter function sales.url_domain(text)        set search_path = pg_catalog;
alter function sales.set_updated_at()        set search_path = pg_catalog;
alter function sales.touch_updated_at()      set search_path = pg_catalog;
alter function sales.is_blocked(text[])      set search_path = sales, pg_catalog;
