\set ON_ERROR_STOP on
begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000001');
insert into profiles(id,name,role) values ('00000000-0000-0000-0000-000000000001','Admin','admin');
insert into clients(id,name,phone) values ('10000000-0000-0000-0000-000000000001','Cliente','123');
insert into orders(client_id,due_at,created_by,total_minor)
select '10000000-0000-0000-0000-000000000001',now()+interval '1 minute','00000000-0000-0000-0000-000000000001',1000 from generate_series(1,30);
insert into payments(order_id,amount_minor,method,created_by,idempotency_key) select id,200,'cash',created_by,gen_random_uuid() from orders limit 1;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare s jsonb; begin
 s:=dashboard_summary();
 if (s->>'active_orders')::int<>30 or (s->>'outstanding_minor')::bigint<>29800 then raise exception 'FAIL: aggregate truncated or wrong balance'; end if;
 if ('2026-10-09T04:59:00Z'::timestamptz at time zone 'America/Bogota')::date <> '2026-10-08'::date then raise exception 'FAIL: day boundary'; end if;
 if ('2026-10-09T05:00:00Z'::timestamptz at time zone 'America/Bogota')::date <> '2026-10-09'::date then raise exception 'FAIL: day boundary'; end if;
end $$;
rollback;
\echo DASHBOARD TESTS PASSED
