create function public.create_order(p_client_id uuid,p_due_at timestamptz,p_notes text,p_items jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare oid uuid:=gen_random_uuid(); item jsonb; svc public.services; qty bigint; subtotal bigint; total bigint:=0; snapshots jsonb:='[]';
begin
 if not public.is_staff() then raise insufficient_privilege using message='Acceso denegado'; end if;
 perform 1 from public.clients where id=p_client_id and active for share;
 if not found then raise check_violation using message='Cliente no disponible'; end if;
 if p_due_at is null or p_due_at<now() or p_items is null or jsonb_typeof(p_items)<>'array' then raise check_violation using message='Fecha o detalle inválido'; end if;
 if jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>100 then raise check_violation using message='Agrega entre 1 y 100 servicios'; end if;
 for item in select value from jsonb_array_elements(p_items) loop
  select * into svc from public.services where id=(item->>'service_id')::uuid and active for share;
  if not found then raise check_violation using message='Servicio no disponible'; end if;
  if item->>'expected_unit' is distinct from svc.unit or item->>'expected_price_minor' is distinct from svc.price_minor::text then
   raise check_violation using message='El precio o la unidad cambiaron. Quita y agrega el servicio para revisar el pedido.';
  end if;
  if coalesce(item->>'quantity','') !~ '^[0-9]+$' then raise check_violation using message='Cantidad inválida'; end if;
  qty:=(item->>'quantity')::bigint;
  if qty<1 or qty>1000000 then raise check_violation using message='Cantidad fuera de rango'; end if;
  subtotal:=case when svc.unit='piece' then svc.price_minor*qty else (svc.price_minor*qty+500)/1000 end;
  if subtotal<1 then raise check_violation using message='Importe demasiado pequeño'; end if;
  total:=total+subtotal;
  if total>9000000000000000 then raise check_violation using message='Total fuera de rango'; end if;
  snapshots:=snapshots||jsonb_build_object('service_id',svc.id,'service_name',svc.name,'unit',svc.unit,'price_minor',svc.price_minor,'quantity',qty,'subtotal_minor',subtotal);
 end loop;
 insert into public.orders(id,client_id,due_at,notes,created_by,total_minor) values(oid,p_client_id,p_due_at,p_notes,auth.uid(),total);
 insert into public.order_items(order_id,service_id,service_name,unit,price_minor,quantity,subtotal_minor)
 select oid,x.service_id,x.service_name,x.unit,x.price_minor,x.quantity,x.subtotal_minor from jsonb_to_recordset(snapshots) as x(service_id uuid,service_name text,unit text,price_minor bigint,quantity bigint,subtotal_minor bigint);
 insert into public.order_events(order_id,to_status,created_by) values(oid,'received',auth.uid());
 return oid;
end $$;
create function public.record_payment(p_order_id uuid,p_amount_minor bigint,p_method text,p_reference text,p_idempotency_key uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare ord public.orders; old public.payments; paid bigint; pid uuid;
begin
 if not public.is_staff() then raise insufficient_privilege using message='Acceso denegado'; end if;
 if p_idempotency_key is null then raise check_violation using message='Falta identificador del pago'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into old from public.payments where idempotency_key=p_idempotency_key;
 if found then
  if old.order_id is distinct from p_order_id or old.amount_minor is distinct from p_amount_minor or old.method is distinct from p_method or old.reference is distinct from p_reference or old.created_by is distinct from auth.uid() then
   raise check_violation using message='El identificador ya corresponde a otro pago';
  end if;
  return old.id;
 end if;
 select * into ord from public.orders where id=p_order_id for update;
 if not found or ord.status in ('cancelled','delivered') then raise check_violation using message='Pedido no disponible para pagos'; end if;
 select coalesce(sum(amount_minor),0) into paid from public.payments where order_id=p_order_id;
 if p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>ord.total_minor-paid or p_method is null or p_method not in ('cash','transfer','card') then raise check_violation using message='Importe o método de pago inválido'; end if;
 insert into public.payments(order_id,amount_minor,method,reference,created_by,idempotency_key) values(p_order_id,p_amount_minor,p_method,p_reference,auth.uid(),p_idempotency_key) returning id into pid;
 return pid;
end $$;
create function public.change_order_status(p_order_id uuid,p_expected_status text,p_next_status text) returns void
language plpgsql security definer set search_path='' as $$
declare ord public.orders; paid bigint;
begin
 if not public.is_staff() then raise insufficient_privilege using message='Acceso denegado'; end if;
 select * into ord from public.orders where id=p_order_id for update;
 if not found or ord.status is distinct from p_expected_status then raise check_violation using message='El pedido cambió; actualiza los datos'; end if;
 select coalesce(sum(amount_minor),0) into paid from public.payments where order_id=p_order_id;
 if not coalesce((ord.status='received' and p_next_status='processing') or (ord.status='processing' and p_next_status='ready') or (ord.status='ready' and p_next_status='delivered' and paid=ord.total_minor) or (ord.status in ('received','processing') and p_next_status='cancelled' and paid=0),false) then
  raise check_violation using message='Cambio de estado no permitido';
 end if;
 update public.orders set status=p_next_status where id=p_order_id;
 insert into public.order_events(order_id,from_status,to_status,created_by) values(p_order_id,ord.status,p_next_status,auth.uid());
end $$;
revoke all on function public.create_order(uuid,timestamptz,text,jsonb),public.record_payment(uuid,bigint,text,text,uuid),public.change_order_status(uuid,text,text) from public;
grant execute on function public.create_order(uuid,timestamptz,text,jsonb),public.record_payment(uuid,bigint,text,text,uuid),public.change_order_status(uuid,text,text) to authenticated;
