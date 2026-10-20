// Github Pages client for Supabase-backed game rooms.
// All authoritative game rules stay in the SQL database function.
let client;
export async function connectRoom({code,key,name,command,onState,onStatus,onError,onIdentity,onMove,onPresence}) {
  const cfg=window.BETWEEN_US_CONFIG||{};
  if(!/^https:\/\/[^/]+\.supabase\.co$/.test(cfg.supabaseUrl||'') || !cfg.supabaseAnonKey) throw Error('Supabase is not configured yet. See SETUP-SUPABASE.md');
  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.76.1');
  client ||= createClient(cfg.supabaseUrl,cfg.supabaseAnonKey,{auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:false}});
  let {data:{session}}=await client.auth.getSession();
  if(!session){ const result=await client.auth.signInAnonymously();if(result.error)throw result.error;session=result.data.session; }
  if(!session)throw Error('Could not sign in anonymously. Enable Anonymous sign-ins in Supabase Auth settings.');
  const id=session.user.id;
  onIdentity(id);
  let stopped=false;
  let syncing=false,queued=false;
  const api=async(cmd,data={})=>{
    const {data:result,error}=await client.functions.invoke('game-api',{body:{code,key,name,command:cmd,data}});
    if(error){let message=error.message;try{const body=await error.context.json();message=body.error||message}catch{}throw Error(message)}
    if(result?.error)throw Error(result.error);
    return result.state;
  };
  const refresh=async()=>{
    if(stopped)return;
    if(syncing){queued=true;return;}
    syncing=true;
    try{onState(await api('state'));onStatus('Connected',true)}catch(e){onError(e.message);onStatus('Reconnecting',false)}
    finally{syncing=false;if(queued){queued=false;refresh()}}
  };
  onStatus('Joining secure room',false);
  onState(await api(command));
  const roomBytes=new TextEncoder().encode(key);
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',roomBytes)),b=>b.toString(16).padStart(2,'0')).join('');
  // Possession of a 192-bit invite token is required to know this room's broadcast topic.
  // Realtime messages carry visual movement only, never answers or secret clues.
  const channel=client.channel(`bu-positions-${code}-${digest.slice(0,22)}`,{config:{broadcast:{self:false},presence:{key:id}}});
  channel.on('broadcast',{event:'position'},({payload})=>{
    if(payload?.id!==id && typeof payload?.id==='string' && Number.isFinite(payload.x) && Number.isFinite(payload.y)){
      onMove(payload.id,Math.max(.13,Math.min(.87,payload.x)),Math.max(.3,Math.min(.78,payload.y)));
    }
  });
  channel.on('presence',{event:'sync'},()=>{const identities=Object.keys(channel.presenceState());onPresence(identities)});
  channel.on('postgres_changes',{event:'INSERT',schema:'public',table:'bu_events',filter:`code=eq.${code}`},()=>refresh());
  channel.subscribe(status=>{onStatus(status==='SUBSCRIBED'?'Connected':status==='CHANNEL_ERROR'?'Network interrupted':'Connecting',status==='SUBSCRIBED');if(status==='SUBSCRIBED')channel.track({nickname:name}).catch(()=>{});});
  // Periodic resync covers dropped change notifications and short suspensions.
  const interval=setInterval(()=>{if(!document.hidden)refresh()},20000);
  return {
    send(action){
      if(stopped)return;
      if(action.kind==='move'){
        channel.send({type:'broadcast',event:'position',payload:{id,x:action.x,y:action.y}});
      } else {
        api('action',action).then(onState).catch(e=>onError(e.message));
      }
    },
    close(){stopped=true;clearInterval(interval);client.removeChannel(channel);},
  };
}
