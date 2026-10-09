\set ON_ERROR_STOP on
begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000001');
insert into profiles(id,name,role) values ('00000000-0000-0000-0000-000000000001','Admin','admin');
insert into clients(id,name,phone) values ('10000000-0000-0000-0000-000000000001','Cliente','123');
insert into services(id,name,unit,price_minor) values ('20000000-0000-0000-0000-000000000001','Lavado','kilogram',1001);
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ begin
 update services set unit='piece';
 begin
  perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1250,"expected_unit":"kilogram","expected_price_minor":1001}]');
  raise exception 'FAIL: stale kilogram draft became 1250 pieces';
 exception when check_violation then null; end;
 update services set unit='kilogram',price_minor=2000;
 begin
  perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1250,"expected_unit":"kilogram","expected_price_minor":1001}]');
  raise exception 'FAIL: price changed without review';
 exception when check_violation then null; end;
 if exists(select 1 from orders) then raise exception 'FAIL: stale draft left order rows'; end if;
end $$;
rollback;
\echo CATALOG CONCURRENCY TESTS PASSED
