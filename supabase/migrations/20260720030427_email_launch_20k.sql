-- Launch tier: email marketing INCLUDED free, up to 20,000/mo (fair-use*).
-- The paid $10 add-on (Startup/Growth) stays at 5,000/mo.
select set_config('app.allow_plan_edit','on',true);
update plan_entitlements set limit_value='20000'
  where plan_id='launch_v1' and feature_key='email.monthly';
