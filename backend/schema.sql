create schema wwm_private;
revoke all on schema wwm_private from public, anon;
grant usage on schema wwm_private to authenticated;
create table wwm_private.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null default 'Du' check(char_length(name) between 1 and 30),
 goal integer not null default 2500 check(goal between 500 and 6000),
 invite text not null unique default left(replace(gen_random_uuid()::text,'-',''),24)
);
create table wwm_private.drinks (
 id uuid primary key, user_id uuid not null references wwm_private.profiles(id) on delete cascade,
 kind text not null check(kind in ('Wasser','Sprudel','Kaffee','Tee','Saft','Softdrink')),
 amount integer not null check(amount between 1 and 3000),
 day date not null default (now() at time zone 'Europe/Berlin')::date,
 created_at timestamptz not null default now()
);
create index wwm_drinks_user_day_time on wwm_private.drinks(user_id,day,created_at desc);
create table wwm_private.friends (
 user_id uuid not null references wwm_private.profiles(id) on delete cascade,
 friend_id uuid not null references wwm_private.profiles(id) on delete cascade,
 primary key(user_id,friend_id),check(user_id<>friend_id)
);
create table wwm_private.cheers (
 drink_id uuid not null references wwm_private.drinks(id) on delete cascade,
 sender_id uuid not null references wwm_private.profiles(id) on delete cascade,
 primary key(drink_id,sender_id)
);
alter table wwm_private.profiles enable row level security;
alter table wwm_private.drinks enable row level security;
alter table wwm_private.friends enable row level security;
alter table wwm_private.cheers enable row level security;
revoke all on all tables in schema wwm_private from public,anon,authenticated;
-- Client roles have no direct table access. Private functions enforce ownership and friendship.
create function wwm_private.state() returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'Europe/Berlin')::date; result jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into wwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 select jsonb_build_object(
 'profile',(select jsonb_build_object('name',name,'goal',goal,'invite',invite) from wwm_private.profiles where id=uid),
 'today',today::text,
 'entries',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000),'cheers',(select count(*) from wwm_private.cheers c where c.drink_id=d.id)) order by d.created_at desc) from wwm_private.drinks d where d.user_id=uid and d.day=today),'[]'::jsonb),
 'week',(select jsonb_agg(jsonb_build_object('day',day::text,'total',coalesce(total,0)) order by day) from (
   select today-g.i as day,(select sum(amount) from wwm_private.drinks where user_id=uid and day=today-g.i) as total from generate_series(0,6) g(i)
 ) w),
 'friends',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'goal',p.goal,'total',coalesce(t.total,0),'drink_id',d.id,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000),'cheered',case when exists(select 1 from wwm_private.cheers c where c.drink_id=d.id and c.sender_id=uid) then 1 else 0 end) order by d.created_at desc nulls last)
 from wwm_private.friends f join wwm_private.profiles p on p.id=f.friend_id
 left join lateral(select sum(amount) total from wwm_private.drinks where user_id=p.id and day=today) t on true
 left join lateral(select * from wwm_private.drinks where user_id=p.id order by created_at desc limit 1) d on true
 where f.user_id=uid),'[]'::jsonb)
 ) into result;
 return result;
end $$;
create function wwm_private.action(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); target uuid; entry uuid; action text:=payload->>'action'; amount integer; new_goal integer; new_name text;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into wwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 if action='drink' then
   if coalesce(payload->>'kind','') not in ('Wasser','Sprudel','Kaffee','Tee','Saft','Softdrink') or coalesce(payload->>'amount','') !~ '^[0-9]{1,4}$' then raise exception 'Ungültiges Getränk oder Menge.';end if;
   amount:=(payload->>'amount')::integer;entry:=(payload->>'id')::uuid;
   if amount<1 or amount>3000 or entry is null then raise exception 'Bitte 1 bis 3.000 ml wählen.';end if;
   if exists(select 1 from wwm_private.drinks where id=entry and user_id<>uid) then raise exception 'Eintrag gehört nicht zu dir.' using errcode='42501';end if;
   insert into wwm_private.drinks(id,user_id,kind,amount) values(entry,uid,payload->>'kind',amount) on conflict(id) do nothing;
 elsif action='delete' then
   delete from wwm_private.drinks where id=(payload->>'id')::uuid and user_id=uid;
 elsif action='profile' then
   new_name:=trim(payload->>'name');
   if coalesce(payload->>'goal','') !~ '^[0-9]{3,4}$' or new_name is null or char_length(new_name) not between 1 and 30 then raise exception 'Bitte Name und Tagesziel prüfen.';end if;
   new_goal:=(payload->>'goal')::integer;if new_goal not between 500 and 6000 then raise exception 'Tagesziel: 500 bis 6.000 ml.';end if;
   update wwm_private.profiles set name=new_name,goal=new_goal where id=uid;
 elsif action='friend' then
   select id into target from wwm_private.profiles where invite=lower(trim(payload->>'code'));
   if target is null or target=uid then raise exception 'Kein gültiger Freundescode.';end if;
   insert into wwm_private.friends(user_id,friend_id) values(uid,target),(target,uid) on conflict do nothing;
 elsif action='unfriend' then
   target:=(payload->>'id')::uuid;
   delete from wwm_private.friends where (user_id=uid and friend_id=target) or (user_id=target and friend_id=uid);
 elsif action='cheer' then
   entry:=(payload->>'id')::uuid;
   if not exists(select 1 from wwm_private.drinks d join wwm_private.friends f on f.friend_id=d.user_id where f.user_id=uid and d.id=entry) then raise exception 'Diesen Eintrag kannst du nicht sehen.' using errcode='42501';end if;
   insert into wwm_private.cheers(drink_id,sender_id) values(entry,uid) on conflict do nothing;
 else raise exception 'Unbekannte Aktion.';end if;
 return wwm_private.state();
end $$;
create function wwm_private.invitation(code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); person wwm_private.profiles;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 if coalesce(code,'') !~ '^[0-9a-fA-F]{24}$' then raise exception 'Ungültige Einladung.';end if;
 select * into person from wwm_private.profiles where invite=lower(code);
 if person.id is null then raise exception 'Diese Einladung ist nicht mehr gültig.';end if;
 if person.id=uid then raise exception 'Das ist dein eigener QR-Code. Lass ihn von deinem Freund scannen.';end if;
 return jsonb_build_object('name',person.name,'alreadyConnected',exists(select 1 from wwm_private.friends where user_id=uid and friend_id=person.id));
end $$;
revoke all on all functions in schema wwm_private from public,anon;
grant execute on all functions in schema wwm_private to authenticated;
create function public.wwm_state() returns jsonb language sql security invoker set search_path='' as $$ select wwm_private.state(); $$;
create function public.wwm_action(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$ select wwm_private.action(payload); $$;
create function public.wwm_invitation(code text) returns jsonb language sql security invoker set search_path='' as $$ select wwm_private.invitation(code); $$;
revoke all on function public.wwm_state(),public.wwm_action(jsonb),public.wwm_invitation(text) from public,anon;
grant execute on function public.wwm_state(),public.wwm_action(jsonb),public.wwm_invitation(text) to authenticated;
