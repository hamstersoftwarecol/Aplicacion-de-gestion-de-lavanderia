\set ON_ERROR_STOP on
begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000001');
insert into profiles(id,name,role) values ('00000000-0000-0000-0000-000000000001','Admin','admin');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into clients(id,name,phone,active) values ('10000000-0000-0000-0000-000000000001','Archived','123',false);
insert into services(id,name,unit,price_minor) values ('20000000-0000-0000-0000-000000000001','Lavado','piece',100);
do $$ declare oid uuid; begin
 begin perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1,"expected_unit":"piece","expected_price_minor":100}]'); raise exception 'FAIL: archived client'; exception when check_violation then null; end;
 update clients set active=true;
 begin perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[]'); raise exception 'FAIL: empty order'; exception when check_violation then null; end;
 begin perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1.5,"expected_unit":"piece","expected_price_minor":100}]'); raise exception 'FAIL: fractional piece'; exception when check_violation then null; end;
 oid:=create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1,"expected_unit":"piece","expected_price_minor":100}]');
 perform change_order_status(oid,'received','cancelled');
 begin perform record_payment(oid,100,'cash',null,gen_random_uuid()); raise exception 'FAIL: cancelled payment'; exception when check_violation then null; end;
 begin perform change_order_status(oid,'cancelled',null); raise exception 'FAIL: null state'; exception when check_violation then null; end;
end $$;
rollback;
\echo INVALID INPUT TESTS PASSED
