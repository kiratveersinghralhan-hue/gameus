-- Phase 9: island travel and shared Mirror Forest challenge. Apply in Supabase SQL Editor AFTER previous migrations.
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
      'clues',jsonb_build_object('sequence',jsonb_build_array('✦','✳','☾','✦','☾','✳'),'attempts',0,'round',0),
      'switch',jsonb_build_object('ready','[]'::jsonb,'step',0),
      'garden',jsonb_build_object('answers','{}'::jsonb,'round',0),
      'island',1,'mirror',jsonb_build_object('step',0));
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
    if game='travel' then
      if (p_data->>'island')::integer = 1 then
        g:=jsonb_set(g,'{island}','1'::jsonb,true);
      elsif (p_data->>'island')::integer = 2 and (done ?& array['same','clues','switch','garden']) then
        g:=jsonb_set(g,'{island}','2'::jsonb,true);
      else raise exception 'Island is still locked'; end if;
    elsif game='mirror' and not(done ? 'mirror') and coalesce((g->>'island')::integer,1)=2 then
      round_no:=coalesce((g#>>'{mirror,step}')::integer,0);
      if myself.slot <> round_no % 2 then raise exception 'Wait for your turn'; end if;
      choice:=p_data->>'side';
      if choice not in ('left','right') then raise exception 'Invalid reflection'; end if;
      if choice = (array['left','right','left','left','right','right'])[round_no+1] then
        round_no:=round_no+1;
        g:=jsonb_set(g,'{mirror,step}',to_jsonb(round_no),true);
        now_completed:=round_no=6;
      else
        g:=jsonb_set(g,'{mirror,step}','0'::jsonb,true);
      end if;
    elsif game='same' and not(done ? 'same') then
      choice:=p_data->>'choice';
      if choice !~ '^[01],[01],[01]$' then raise exception 'Invalid choice'; end if;
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
      round_no:=coalesce((g#>>'{switch,step}')::integer,0);
      if myself.slot <> round_no % 2 then raise exception 'Wait for your turn'; end if;
      round_no:=round_no+1;
      g:=jsonb_set(g,'{switch,step}',to_jsonb(round_no),true);
      now_completed:=round_no>=4;
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
        g:=jsonb_set(g,'{switch}',jsonb_build_object('ready','[]'::jsonb,'step',0));
      elsif game='clues' then
        round_no:=coalesce((g#>>'{clues,round}')::integer,0)+1;
        select jsonb_agg(to_jsonb(symbols[1+floor(random()*3)::integer])) into seq from generate_series(1,6);
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
