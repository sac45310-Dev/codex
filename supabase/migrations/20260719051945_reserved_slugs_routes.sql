-- Reserve the new app-route names (password reset now; URL routing next)
-- so no donation page can ever shadow a route.
create or replace function public.donation_page_slug_guard()
returns trigger language plpgsql as $$
begin
  if new.slug = any (array[
    'admin','api','app','about','assets','blog','contact','dashboard',
    'docs','donate','donations','donors','give','giving','help','home',
    'inbox','index','legal','login','logout','messages','ministries',
    'pay','preview','pricing','privacy','reset','segments','settings',
    'signin','signup','static','support','teams','terms','test','v','www'
  ]) then
    raise exception 'That link name is reserved — please pick another.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;
