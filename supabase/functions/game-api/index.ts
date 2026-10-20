// BETWEEN US: authenticated HTTP gateway, with locked database game commands.
// Deploy with --no-verify-jwt only if keeping the getUser() check below intact.
import { createClient } from 'npm:@supabase/supabase-js@2';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Content-Type': 'application/json',
};
function response(obj: unknown, status=200) { return new Response(JSON.stringify(obj),{status,headers:cors}); }
Deno.serve(async request => {
  if(request.method==='OPTIONS') return new Response(null,{status:204,headers:cors});
  if(request.method!=='POST') return response({error:'Method not allowed'},405);
  try {
    const authorization = request.headers.get('Authorization') || '';
    if (!authorization.startsWith('Bearer ')) return response({error:'Sign in first'},401);
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!url||!anon||!service) return response({error:'Server configuration missing'},503);
    const authClient = createClient(url,anon,{auth:{persistSession:false}});
    const {data:auth,error:authError}=await authClient.auth.getUser(authorization.slice(7));
    if(authError||!auth.user) return response({error:'Authentication failed'},401);
    let data: Record<string,unknown>;
    try { data=await request.json(); } catch { return response({error:'Invalid JSON'},400); }
    if(typeof data.code!=='string'|| !/^[A-Z2-9]{10}$/.test(data.code)
      ||typeof data.key!=='string'||!/^[0-9a-f]{48}$/.test(data.key)
      || !['create','join','state','action'].includes(String(data.command)) )
      return response({error:'Invalid room request'},400);
    if(JSON.stringify(data).length>1600) return response({error:'Request too large'},413);
    const keyBytes = new TextEncoder().encode(data.key);
    const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',keyBytes)),n=>n.toString(16).padStart(2,'0')).join('');
    const admin=createClient(url,service,{auth:{persistSession:false}});
    const {data:state,error}=await admin.rpc('bu_turn',{
      p_code:data.code,p_secret_hash:hash,p_user:auth.user.id,
      p_name:typeof data.name==='string'?data.name.slice(0,18):'Explorer',
      p_command:data.command,p_data:data.data && typeof data.data==='object'&&!Array.isArray(data.data)?data.data:{}
    });
    if(error) {
      const safeMessages=['Invalid invitation','Room not found','Incorrect invitation','Room is full','Join first','Wait for your second player','Invalid choice','Already answered','Only the decoder can submit','Invalid code','Game not completed','Invalid or completed action','Invalid command'];
      const publicMessage=safeMessages.find(m=>error.message.includes(m)) || 'Could not process action';
      return response({error:publicMessage},400);
    }
    return response({state});
  } catch { return response({error:'Unexpected server error'},500); }
});
