-- BETWEEN US / Supabase game rooms. Run once in the Supabase SQL editor.
create extension if not exists pgcrypto;
create table if not exists public.bu_rooms (
  code text primary key check (code ~ '^[A-Z2-9]{10}$'),
  secret_hash text not null,
  game_state jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.bu_members (
  code text not null references public.bu_rooms(code) on delete cascade,
  user_id uuid not null,
  slot smallint not null check (slot in (0,1)),
  name text not null,
  primary key(code,user_id),
  unique(code,slot)
);
create table if not exists public.bu_events (
  id bigint generated always as identity primary key,
  code text not null references public.bu_rooms(code) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists bu_events_room_idx on public.bu_events(code,id desc);
alter table public.bu_rooms enable row level security;
alter table public.bu_members enable row level security;
alter table public.bu_events enable row level security;
-- Game state, invitations and membership cannot be read/written via the public API.
revoke all on public.bu_rooms, public.bu_members from anon, authenticated;
revoke all on public.bu_events from anon, authenticated;
grant select on public.bu_events to authenticated;
-- The authenticated client cannot read the private membership table directly.
-- A narrowly-scoped security-definer function checks only current-user membership.
create or replace function public.bu_can_receive(p_code text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.bu_members m
    where m.code=p_code and m.user_id=(select auth.uid()))
$$;
revoke all on function public.bu_can_receive(text) from public, anon;
grant execute on function public.bu_can_receive(text) to authenticated;
create policy "only participants receive game refresh events" on public.bu_events for select to authenticated
using (public.bu_can_receive(code));
do $$ begin
  alter publication supabase_realtime add table public.bu_events;
exception when duplicate_object then null;
end $$;

-- Every mutation and snapshot is performed under a row lock by the service role.
-- Client credentials cannot execute this function directly.
create or replace function public.bu_turn(
  p_code text, p_secret_hash text, p_user uuid,
  p_name text, p_command text, p_data jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r public.bu_rooms%rowtype;
  g jsonb;
  myself record;
  slot_count integer;
  done jsonb;
  game text;
  choice text;
  answer text;
  now_completed boolean := false;
  idx integer;
  other_id text;
  round_no integer;
  seq jsonb;
  symbols text[] := array['✦','☾','✳'];
  projected jsonb;
  players jsonb;
  view_answers jsonb;
  oldpoint jsonb;
  x numeric;
  y numeric;
begin
  if p_code !~ '^[A-Z2-9]{10}$' or p_secret_hash !~ '^[0-9a-f]{64}$' or p_user is null then
    raise exception 'Invalid invitation';
  end if;
  select * into r from public.bu_rooms where code=p_code for update;
  if not found then
    if p_command <> 'create' then raise exception 'Room not found'; end if;
    g := jsonb_build_object('players','[]'::jsonb,'completed','[]'::jsonb,
      'same',jsonb_build_object('answers','{}'::jsonb,'round',0),
      'clues',jsonb_build_object('sequence',jsonb_build_array('✦','✳','☾','✦'),'attempts',0,'round',0),
      'switch',jsonb_build_object('ready','[]'::jsonb),
      'garden',jsonb_build_object('answers','{}'::jsonb,'round',0));
    insert into public.bu_rooms(code,secret_hash,game_state) values(p_code,p_secret_hash,g);
    select * into r from public.bu_rooms where code=p_code for update;
  end if;
  if r.secret_hash <> p_secret_hash then raise exception 'Incorrect invitation'; end if;
  select slot, name into myself from public.bu_members where code=p_code and user_id=p_user;
  if not found then
    if p_command not in ('create','join') then raise exception 'Join first'; end if;
    select count(*) into slot_count from public.bu_members where code=p_code;
    if slot_count >= 2 then raise exception 'Room is full'; end if;
    insert into public.bu_members(code,user_id,slot,name) values(p_code,p_user,slot_count,left(regexp_replace(coalesce(p_name,'Explorer'),'[<>]','','g'),18));
    myself.slot := slot_count;
  elsif p_command in ('create','join') then
    update public.bu_members set name=left(regexp_replace(coalesce(p_name,'Explorer'),'[<>]','','g'),18) where code=p_code and user_id=p_user;
  end if;
  g:=r.game_state;
  select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id::text,'name',m.name,
    'x',case when m.slot=0 then 0.35 else 0.65 end,'y',0.53,'online',true) order by m.slot),'[]'::jsonb)
    into players from public.bu_members m where m.code=p_code;
  g:=jsonb_set(g,'{players}',players);
  done:=g->'completed';
  if p_command='action' then
    game:=p_data->>'kind';
    select count(*) into slot_count from public.bu_members where code=p_code;
    if slot_count<>2 then raise exception 'Wait for your second player'; end if;
    if game='same' and not(done ? 'same') then
      choice:=p_data->>'choice';
      if choice not in ('beach','mountains') then raise exception 'Invalid choice'; end if;
      if (g#>'{same,answers}') ? p_user::text then raise exception 'Already answered'; end if;
      g:=jsonb_set(g,array['same','answers',p_user::text],to_jsonb(choice),true);
      if public.jsonb_object_length_safe(g#>'{same,answers}')=2 then now_completed:=true; end if;
    elsif game='garden' and not(done ? 'garden') then
      choice:=p_data->>'choice';
      if choice not in ('star','moon','sun') then raise exception 'Invalid choice'; end if;
      if (g#>'{garden,answers}') ? p_user::text then raise exception 'Already answered'; end if;
      g:=jsonb_set(g,array['garden','answers',p_user::text],to_jsonb(choice),true);
      if public.jsonb_object_length_safe(g#>'{garden,answers}')=2 then now_completed:=true; end if;
    elsif game='clues' and not(done ? 'clues') then
      round_no:=coalesce((g#>>'{clues,round}')::integer,0);
      if myself.slot <> (1 - round_no % 2) then raise exception 'Only the decoder can submit'; end if;
      answer:=p_data->>'answer';
      if length(coalesce(answer,''))>20 then raise exception 'Invalid code'; end if;
      g:=jsonb_set(g,'{clues,attempts}',to_jsonb(coalesce((g#>>'{clues,attempts}')::integer,0)+1));
      select string_agg(value #>> '{}','' order by ord) into choice from jsonb_array_elements(g#>'{clues,sequence}') with ordinality as t(value,ord);
      now_completed:=answer=choice;
    elsif game='switch' and not(done ? 'switch') then
      if not ((g#>'{switch,ready}') ? p_user::text) then
        g:=jsonb_set(g,'{switch,ready}',(g#>'{switch,ready}') || to_jsonb(p_user::text));
      end if;
      now_completed:=jsonb_array_length(g#>'{switch,ready}')=2;
    elsif game='reset' then
      game:=p_data->>'game';
      if game not in ('same','clues','switch','garden') or not(done ? game) then raise exception 'Game not completed'; end if;
      select coalesce(jsonb_agg(value),'[]'::jsonb) into done from jsonb_array_elements_text(done) as t(value) where value<>game;
      g:=jsonb_set(g,'{completed}',done);
      if game='same' then
        round_no:=coalesce((g#>>'{same,round}')::integer,0)+1;
        g:=jsonb_set(g,'{same}',jsonb_build_object('answers','{}'::jsonb,'round',round_no));
      elsif game='garden' then
        round_no:=coalesce((g#>>'{garden,round}')::integer,0)+1;
        g:=jsonb_set(g,'{garden}',jsonb_build_object('answers','{}'::jsonb,'round',round_no));
      elsif game='switch' then
        g:=jsonb_set(g,'{switch}',jsonb_build_object('ready','[]'::jsonb));
      elsif game='clues' then
        round_no:=coalesce((g#>>'{clues,round}')::integer,0)+1;
        select jsonb_agg(to_jsonb(symbols[1+floor(random()*3)::integer])) into seq from generate_series(1,4);
        g:=jsonb_set(g,'{clues}',jsonb_build_object('sequence',seq,'attempts',0,'round',round_no));
      end if;
    else raise exception 'Invalid or completed action';
    end if;
    if now_completed then g:=jsonb_set(g,'{completed}',(g->'completed') || to_jsonb(game)); end if;
  elsif p_command not in ('create','join','state') then
    raise exception 'Invalid command';
  end if;
  if p_command <> 'state' then
    update public.bu_rooms set game_state=g,updated_at=now() where code=p_code;
    insert into public.bu_events(code) values(p_code);
  end if;
  projected:=g;
  if not ((g->'completed') ? 'same') then
    view_answers:='{}'::jsonb;
    if (g#>'{same,answers}') ? p_user::text then
      view_answers:=jsonb_build_object(p_user::text,g#>array['same','answers',p_user::text]);
    end if;
    projected:=jsonb_set(projected,'{same,answers}',view_answers);
  end if;
  if not ((g->'completed') ? 'garden') then
    view_answers:='{}'::jsonb;
    if (g#>'{garden,answers}') ? p_user::text then
      view_answers:=jsonb_build_object(p_user::text,g#>array['garden','answers',p_user::text]);
    end if;
    projected:=jsonb_set(projected,'{garden,answers}',view_answers);
  end if;
  round_no:=coalesce((g#>>'{clues,round}')::integer,0);
  if myself.slot <> round_no % 2 and not ((g->'completed') ? 'clues') then
    projected:=jsonb_set(projected,'{clues,sequence}','[]'::jsonb);
  end if;
  return projected;
end $$;
-- Safe jsonb object cardinality for answers.
create or replace function public.jsonb_object_length_safe(p jsonb)
returns integer language sql immutable set search_path='' as $$
select count(*)::integer from jsonb_object_keys(coalesce(p,'{}'::jsonb)) $$;
revoke all on function public.bu_turn(text,text,uuid,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.bu_turn(text,text,uuid,text,text,jsonb) to service_role;
revoke all on function public.jsonb_object_length_safe(jsonb) from public, anon, authenticated;
grant execute on function public.jsonb_object_length_safe(jsonb) to service_role;
-- Keep the notification table small for public growth. Schedule periodic cleanup in production.
