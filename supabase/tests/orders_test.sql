\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(ok boolean,label text) returns void language plpgsql as $$ begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
insert into auth.users values ('00000000-0000-0000-0000-000000000001');
insert into profiles(id,name,role) values ('00000000-0000-0000-0000-000000000001','Admin','admin');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into clients(id,name,phone) values ('10000000-0000-0000-0000-000000000001','Cliente','123');
insert into services(id,name,unit,price_minor) values ('20000000-0000-0000-0000-000000000001','Lavado','kilogram',1001);
do $$ declare oid uuid; pid uuid; pid2 uuid; n int; begin
 oid:=create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1500,"expected_unit":"kilogram","expected_price_minor":1001}]');
 perform pg_temp.assert_true((select total_minor=1502 from orders where id=oid),'half up server total');
 update services set price_minor=9999;
 perform pg_temp.assert_true((select price_minor=1001 from order_items where order_id=oid),'historical price');
 begin perform change_order_status(oid,'received','delivered'); raise exception 'FAIL: skipped statuses'; exception when check_violation then null; end;
 pid:=record_payment(oid,500,'cash',null,'30000000-0000-0000-0000-000000000001');
 pid2:=record_payment(oid,500,'cash',null,'30000000-0000-0000-0000-000000000001');
 perform pg_temp.assert_true(pid=pid2,'idempotent payment');
 perform pg_temp.assert_true((select count(*)=1 from payments where order_id=oid),'one payment row');
 begin perform record_payment(oid,501,'cash',null,'30000000-0000-0000-0000-000000000001'); raise exception 'FAIL: different retry accepted'; exception when check_violation then null; end;
 begin perform record_payment(oid,1003,'cash',null,gen_random_uuid()); raise exception 'FAIL: overpayment'; exception when check_violation then null; end;
 begin perform record_payment(oid,0,'cash',null,gen_random_uuid()); raise exception 'FAIL: zero payment'; exception when check_violation then null; end;
 begin perform change_order_status(oid,'received','cancelled'); raise exception 'FAIL: cancel paid'; exception when check_violation then null; end;
 perform change_order_status(oid,'received','processing');
 begin perform change_order_status(oid,'received','processing'); raise exception 'FAIL: stale status'; exception when check_violation then null; end;
 perform change_order_status(oid,'processing','ready');
 begin perform change_order_status(oid,'ready','delivered'); raise exception 'FAIL: unpaid delivery'; exception when check_violation then null; end;
 perform record_payment(oid,1002,'transfer','ref',gen_random_uuid());
 perform change_order_status(oid,'ready','delivered');
 perform pg_temp.assert_true((select count(*)=4 from order_events where order_id=oid),'all status events');
 n:=(select count(*) from orders);
 begin perform create_order('10000000-0000-0000-0000-000000000001',now()-interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1,"expected_unit":"kilogram","expected_price_minor":1001}]'); raise exception 'FAIL: past date'; exception when check_violation then null; end;
 update services set active=false;
 begin perform create_order('10000000-0000-0000-0000-000000000001',now()+interval '1 day','', '[{"service_id":"20000000-0000-0000-0000-000000000001","quantity":1,"expected_unit":"kilogram","expected_price_minor":1001}]'); raise exception 'FAIL: inactive service'; exception when check_violation then null; end;
 perform pg_temp.assert_true((select count(*)=n from orders),'failed creation atomic');
end $$;
rollback;
\echo ORDER TESTS PASSED
