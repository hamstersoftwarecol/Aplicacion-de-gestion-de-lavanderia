create function public.dashboard_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.is_staff() then raise insufficient_privilege using message='Acceso denegado'; end if;
 select jsonb_build_object(
 'active_orders',count(*) filter(where status in ('received','processing','ready')),
 'due_today',count(*) filter(where status in ('received','processing','ready') and (due_at at time zone 'America/Bogota')::date=(now() at time zone 'America/Bogota')::date),
 'outstanding_minor',coalesce(sum(total_minor-coalesce(p.paid,0)) filter(where status<>'cancelled'),0)) into result
 from public.orders o left join (select order_id,sum(amount_minor) paid from public.payments group by order_id) p on p.order_id=o.id;
 return result;
end $$;
revoke all on function public.dashboard_summary() from public;
grant execute on function public.dashboard_summary() to authenticated;
