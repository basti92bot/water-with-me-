-- Release 1.3: optional, per-drink approximate location and authorized pop-ups.
create or replace function wwm_private.location_valid(place jsonb) returns boolean language sql immutable security invoker set search_path='' as $$
 select case when place is null or place='null'::jsonb then true
 when jsonb_typeof(place)='object' and jsonb_typeof(place->'lat')='number' and jsonb_typeof(place->'lon')='number'
 and (not place?'label' or jsonb_typeof(place->'label')='string') then
 (place->>'lat')::numeric between -90 and 90 and (place->>'lon')::numeric between -180 and 180
 and char_length(coalesce(place->>'label',''))<=40 and coalesce(place->>'label','') !~ '[[:cntrl:]]'
 else false end;
$$;
revoke all on function wwm_private.location_valid(jsonb) from public,anon,authenticated;
alter table wwm_private.drinks add column location jsonb;
alter table wwm_private.drinks add constraint drinks_location_check check(wwm_private.location_valid(location));
CREATE OR REPLACE FUNCTION wwm_private.action(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); target uuid; entry uuid; action text:=payload->>'action'; amount integer; new_goal integer; new_name text; place jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into wwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 if action='drink' then
   if coalesce(payload->>'kind','') not in ('Wasser','Sprudel','Kaffee','Tee','Saft','Softdrink','Monster Energy') or coalesce(payload->>'amount','') !~ '^[0-9]{1,4}$' then raise exception 'Ungültiges Getränk oder Menge.';end if;
   amount:=(payload->>'amount')::integer;entry:=(payload->>'id')::uuid;
   if amount<1 or amount>3000 or entry is null then raise exception 'Bitte 1 bis 3.000 ml wählen.';end if;
   if exists(select 1 from wwm_private.drinks where id=entry and user_id<>uid) then raise exception 'Eintrag gehört nicht zu dir.' using errcode='42501';end if;
   if not wwm_private.location_valid(payload->'location') then raise exception 'Bitte einen gültigen Standort wählen.';end if;
   if payload->'location' is not null and payload->'location'<>'null'::jsonb then
     place:=jsonb_build_object('lat',round((payload#>>'{location,lat}')::numeric,3),'lon',round((payload#>>'{location,lon}')::numeric,3),'label',trim(coalesce(payload#>>'{location,label}','')));
   end if;
   insert into wwm_private.drinks(id,user_id,kind,amount,location) values(entry,uid,payload->>'kind',amount,place) on conflict(id) do nothing;
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
end $function$
;
CREATE OR REPLACE FUNCTION wwm_private.state()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'Europe/Berlin')::date; result jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 insert into wwm_private.profiles(id) values(uid) on conflict(id) do nothing;
 select jsonb_build_object(
 'profile',(select jsonb_build_object('name',name,'goal',goal,'invite',invite) from wwm_private.profiles where id=uid),
 'today',today::text,
 'entries',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'kind',d.kind,'amount',d.amount,'has_location',d.location is not null,'created_at',floor(extract(epoch from d.created_at)*1000),'cheers',(select count(*) from wwm_private.cheers c where c.drink_id=d.id)) order by d.created_at desc) from wwm_private.drinks d where d.user_id=uid and d.day=today),'[]'::jsonb),
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
end $function$
;
CREATE OR REPLACE FUNCTION wwm_private.push_claim(token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare config wwm_private.push_config;expected text; private_key text; jobs jsonb;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Nicht erlaubt.' using errcode='42501';end if;
 select * into config from wwm_private.push_config where enabled;
 select decrypted_secret into expected from vault.decrypted_secrets where id=config.dispatch_secret;
 if expected is null or token is null or token<>expected then raise exception 'Nicht erlaubt.' using errcode='42501';end if;
 select decrypted_secret into private_key from vault.decrypted_secrets where id=config.private_secret;
 delete from wwm_private.push_jobs j where j.created_at<=now()-interval '15 minutes' or j.attempts>=5 or (j.drink_id is not null and not exists(select 1 from wwm_private.drinks d join wwm_private.push_devices s on s.id=j.device_id join wwm_private.friends f on f.user_id=d.user_id and f.friend_id=s.user_id where d.id=j.drink_id));
 with due as (select id from wwm_private.push_jobs where next_attempt<=now() order by created_at limit 40 for update skip locked), claimed as (update wwm_private.push_jobs j set lease=gen_random_uuid(),attempts=j.attempts+1,next_attempt=now()+interval '2 minutes' from due where due.id=j.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'lease',j.lease,'endpoint',s.endpoint,'keys',jsonb_build_object('p256dh',s.p256dh,'auth',s.auth_key),'payload',case when j.drink_id is null then jsonb_build_object('title','Water With Me 💧','body','Push-Mitteilungen sind aktiviert.','tag','wwm-test') else jsonb_build_object('title','Water With Me 💧','body',p.name||' hat gerade '||d.amount||' ml '||d.kind||' getrunken.'||case when d.location is null then '' else E'\n📍 '||case when coalesce(d.location->>'label','')<>'' then d.location->>'label'||' · ' else '' end||(d.location->>'lat')||', '||(d.location->>'lon') end,'tag','wwm-'||d.id,'drinkId',d.id) end)), '[]'::jsonb) into jobs from claimed j join wwm_private.push_devices s on s.id=j.device_id left join wwm_private.drinks d on d.id=j.drink_id left join wwm_private.profiles p on p.id=d.user_id;
 return jsonb_build_object('vapid',jsonb_build_object('subject','https://basti92bot.github.io/water-with-me-/','publicKey',config.public_key,'privateKey',private_key),'jobs',jobs);
end $function$
;
create or replace function wwm_private.notification(entry_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); notice jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden.' using errcode='42501';end if;
 select jsonb_build_object('id',d.id,'name',p.name,'kind',d.kind,'amount',d.amount,'created_at',floor(extract(epoch from d.created_at)*1000),'location',d.location) into notice
 from wwm_private.drinks d join wwm_private.profiles p on p.id=d.user_id
 where d.id=entry_id and (d.user_id=uid or exists(select 1 from wwm_private.friends f where f.user_id=uid and f.friend_id=d.user_id));
 if notice is null then raise exception 'Diesen Eintrag kannst du nicht sehen.' using errcode='42501';end if;
 return notice;
end $$;
revoke all on function wwm_private.notification(uuid) from public,anon,authenticated;
grant execute on function wwm_private.notification(uuid) to authenticated;
create or replace function public.wwm_notification(entry_id uuid) returns jsonb language sql security invoker set search_path='' as $$select wwm_private.notification(entry_id);$$;
revoke all on function public.wwm_notification(uuid) from public,anon,authenticated;
grant execute on function public.wwm_notification(uuid) to authenticated;
