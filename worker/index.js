// Cloudflare Worker + Durable Object authoritative two-player game room.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/api\/room\/([A-Z2-9]{10})$/);
    if (!match) return env.ASSETS.fetch(request);
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return new Response('WebSocket required', { status: 426 });
    const id=env.ROOMS.idFromName(match[1]);
    return env.ROOMS.get(id).fetch(request);
  }
};
const symbols=['✦','☾','✳'];
const initial=()=>({players:[],completed:[],same:{answers:{},round:0},clues:{sequence:['✦','✳','☾','✦'],attempts:0},switch:{ready:[]},started:Date.now()});
const cleanName=s=>String(s||'Explorer').replace(/[\x00-\x1f<>]/g,'').slice(0,18)||'Explorer';
export class GameRoom {
  constructor(ctx,env){this.ctx=ctx;this.env=env;this.state=null;this.key=null;this.sessions=new Map();this.ready=this.init()}
  async init(){const stored=await this.ctx.storage.get(['state','inviteKey']);this.state=stored.get('state')||initial();this.key=stored.get('inviteKey')||null;for(const ws of this.ctx.getWebSockets()){try{let att=ws.deserializeAttachment();if(att?.id)this.sessions.set(att.id,ws)}catch{}}}
  async fetch(request){await this.ready;const u=new URL(request.url);const key=u.searchParams.get('key'),id=u.searchParams.get('id'),name=cleanName(u.searchParams.get('name'));
    if(!key||key.length!==48||!/^[0-9a-f]{48}$/.test(key)||!id||id.length>80)return new Response('Invalid invitation', {status:403});
    if(this.key&&this.key!==key)return new Response('Invalid invitation', {status:403});
    const exists=this.state.players.find(p=>p.id===id);if(!exists&&this.state.players.length>=2)return new Response('Room full', {status:409});
    if(!this.key){this.key=key;await this.ctx.storage.put('inviteKey',key)}
    const pair=new WebSocketPair();const client=pair[0],server=pair[1];this.ctx.acceptWebSocket(server);
    const previous=this.sessions.get(id);if(previous){try{previous.close(4000,'Replaced by new connection')}catch{}}
    this.sessions.set(id,server);server.serializeAttachment({id});
    if(exists){exists.name=name;exists.online=true}else this.state.players.push({id,name,x:this.state.players.length?.65:.35,y:.53,online:true});
    await this.save();this.broadcast();return new Response(null,{status:101,webSocket:client});
  }
  async webSocketMessage(ws,message){await this.ready;const att=ws.deserializeAttachment();if(!att?.id||this.sessions.get(att.id)!==ws)return;let msg;try{if(typeof message!=='string'||message.length>1000)return;msg=JSON.parse(message)}catch{return}if(msg?.type!=='action')return;
    const id=att.id,s=this.state,player=s.players.find(p=>p.id===id);if(!player)return;
    if(msg.kind==='move') {const x=Number(msg.x),y=Number(msg.y);if(!Number.isFinite(x)||!Number.isFinite(y))return;player.x=Math.max(.13,Math.min(.87,x));player.y=Math.max(.3,Math.min(.78,y));this.broadcast();return}
    if(msg.kind==='same'&&!s.completed.includes('same')&&s.players.length===2){if(!['beach','mountains'].includes(msg.choice)||s.same.answers[id])return;s.same.answers[id]=msg.choice;if(s.players.every(p=>s.same.answers[p.id]))s.completed.push('same')}
    else if(msg.kind==='clues'&&!s.completed.includes('clues')&&s.players.length===2){if(s.players[1]?.id!==id||!Array.isArray(s.clues.sequence)||typeof msg.answer!=='string'||msg.answer.length>20)return;s.clues.attempts++;if(msg.answer===s.clues.sequence.join(''))s.completed.push('clues')}
    else if(msg.kind==='switch'&&!s.completed.includes('switch')&&s.players.length===2){if(!s.switch.ready.includes(id))s.switch.ready.push(id);if(s.switch.ready.length===2)s.completed.push('switch')}
    else if(msg.kind==='reset'&&['same','clues','switch'].includes(msg.game)&&s.completed.includes(msg.game)){s.completed=s.completed.filter(v=>v!==msg.game);if(msg.game==='same')s.same={answers:{},round:s.same.round+1};if(msg.game==='clues')s.clues={sequence:['✦','✳','☾','✦'],attempts:0};if(msg.game==='switch')s.switch={ready:[]}}
    else return;
    await this.save();this.broadcast();
  }
  async webSocketClose(ws){await this.ready;this.detach(ws)}
  async webSocketError(ws){await this.ready;this.detach(ws)}
  detach(ws){let id;try{id=ws.deserializeAttachment()?.id}catch{}if(!id||this.sessions.get(id)!==ws)return;this.sessions.delete(id);let p=this.state.players.find(p=>p.id===id);if(p)p.online=false;this.ctx.storage.put('state',this.state);this.broadcast()}
  async save(){await this.ctx.storage.put('state',this.state)}
  broadcast(){for(const ws of this.ctx.getWebSockets()){let id;try{id=ws.deserializeAttachment()?.id}catch{continue}if(this.sessions.get(id)!==ws)continue;try{ws.send(JSON.stringify({type:'state',state:this.forPlayer(id)}))}catch{}}}
  forPlayer(id){const s=this.state;return {...s,same:{...s.same,answers:s.completed.includes('same')?s.same.answers:(s.same.answers[id]?{[id]:s.same.answers[id]}:{})},clues:{...s.clues,sequence:s.players[0]?.id===id||s.completed.includes('clues')?s.clues.sequence:[]}}}
}
