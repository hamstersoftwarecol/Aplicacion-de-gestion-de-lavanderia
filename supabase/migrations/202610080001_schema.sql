create table public.profiles (
 id uuid primary key references auth.users(id) on delete restrict,
 name text not null check (length(trim(name)) > 0),
 role text not null default 'employee' check(role in ('admin','employee')),
 active boolean not null default true
);
create table public.clients (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0),
 phone text not null check(length(trim(phone))>0), email text, notes text,
 active boolean not null default true, created_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0),
 unit text not null check(unit in ('piece','kilogram')),
 price_minor bigint not null check(price_minor between 1 and 1000000000000), active boolean not null default true
);
create table public.orders (
 id uuid primary key default gen_random_uuid(), number bigint generated always as identity unique,
 client_id uuid not null references public.clients(id),
 status text not null default 'received' check(status in ('received','processing','ready','delivered','cancelled')),
 received_at timestamptz not null default now(), due_at timestamptz not null,
 notes text, created_by uuid not null references public.profiles(id),
 total_minor bigint not null check(total_minor between 1 and 9000000000000000),
 check(due_at >= received_at)
);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
 service_id uuid not null references public.services(id), service_name text not null,
 unit text not null check(unit in ('piece','kilogram')), price_minor bigint not null check(price_minor>0),
 quantity bigint not null check(quantity between 1 and 1000000), subtotal_minor bigint not null check(subtotal_minor>0)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
 amount_minor bigint not null check(amount_minor>0), method text not null check(method in ('cash','transfer','card')),
 reference text, created_at timestamptz not null default now(), created_by uuid not null references public.profiles(id),
 idempotency_key uuid not null unique
);
create table public.order_events (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
 from_status text, to_status text not null, created_at timestamptz not null default now(),
 created_by uuid not null references public.profiles(id)
);
create index on public.clients(name,id);
create index on public.orders(received_at desc,id);
create index on public.orders(client_id);
create index on public.orders(status,due_at);
create index on public.order_items(order_id);
create index on public.payments(order_id);
create index on public.order_events(order_id,created_at);
create function public.is_staff() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and active);
$$;
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and active and role='admin');
$$;
revoke all on function public.is_staff(), public.is_admin() from public;
grant execute on function public.is_staff(), public.is_admin() to authenticated, anon;

do $$ declare t text; begin
 foreach t in array array['profiles','clients','services','orders','order_items','payments','order_events'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select on public.%I to anon, authenticated',t);
  execute format('create policy staff_read on public.%I for select using (public.is_staff())',t);
 end loop;
end $$;
grant usage on schema public to anon, authenticated;
grant insert,update on public.clients, public.services to authenticated;
create policy staff_insert on public.clients for insert to authenticated with check(public.is_staff());
create policy staff_update on public.clients for update to authenticated using(public.is_staff()) with check(public.is_staff());
create policy admin_insert on public.services for insert to authenticated with check(public.is_admin());
create policy admin_update on public.services for update to authenticated using(public.is_admin()) with check(public.is_admin());

create function public.set_profile_access(p_profile_id uuid,p_role text,p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
 perform pg_advisory_xact_lock(714218);
 if not public.is_admin() then raise insufficient_privilege using message='Acceso denegado'; end if;
 if p_role not in ('admin','employee') or p_role is null or p_active is null then raise check_violation using message='Perfil inválido'; end if;
 if not exists(select 1 from public.profiles where id=p_profile_id) then raise check_violation using message='Perfil inexistente'; end if;
 if (p_role <> 'admin' or not p_active) and not exists(select 1 from public.profiles where id<>p_profile_id and role='admin' and active) then
  raise check_violation using message='Debe permanecer un administrador activo';
 end if;
 update public.profiles set role=p_role,active=p_active where id=p_profile_id;
end $$;
revoke all on function public.set_profile_access(uuid,text,boolean) from public;
grant execute on function public.set_profile_access(uuid,text,boolean) to authenticated;
