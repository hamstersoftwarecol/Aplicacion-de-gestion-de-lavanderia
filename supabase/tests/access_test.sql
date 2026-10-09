\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$ begin if ok is distinct from true then raise exception 'FAIL: %', label; end if; end $$;
insert into auth.users values ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
insert into public.profiles(id,name,role) values ('00000000-0000-0000-0000-000000000001','Admin','admin'),('00000000-0000-0000-0000-000000000002','Empleado','employee'),('00000000-0000-0000-0000-000000000003','Segundo','admin');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
insert into clients(name,phone) values ('Cliente','123');
select pg_temp.assert_true((select count(*)=1 from clients),'employee reads clients');
do $$ begin
  begin insert into services(name,unit,price_minor) values ('Lavado','piece',100); raise exception 'FAIL: employee wrote catalog'; exception when insufficient_privilege then null; end;
  begin update profiles set role='admin' where id=auth.uid(); raise exception 'FAIL: employee promoted'; exception when insufficient_privilege then null; end;
  begin perform set_profile_access(auth.uid(),'admin',true); raise exception 'FAIL: employee RPC promoted'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into services(name,unit,price_minor) values ('Lavado','piece',100);
select set_profile_access('00000000-0000-0000-0000-000000000003','employee',false);
do $$ begin
 begin perform set_profile_access(auth.uid(),'employee',false); raise exception 'FAIL: removed last admin'; exception when check_violation then null; end;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
select pg_temp.assert_true((select count(*)=0 from clients),'inactive cannot read clients');
select pg_temp.assert_true((select count(*)=0 from services),'inactive cannot read services');
set local role anon;
select pg_temp.assert_true((select count(*)=0 from clients),'anonymous cannot read clients');
reset role;
select pg_temp.assert_true(not has_table_privilege('authenticated','public.payments','INSERT'),'no direct payment writes');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.orders','UPDATE'),'no direct order updates');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.order_events','INSERT'),'no history writes');
rollback;
\echo ACCESS TESTS PASSED
