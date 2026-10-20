import test from 'node:test';
import assert from 'node:assert/strict';
import {GameRoom} from '../worker/index.js';

function fixture(){
  const store=new Map();
  const sockets=[];
  const context={storage:{async get(keys){return new Map(keys.map(k=>[k,store.get(k)]))},async put(k,v){store.set(k,structuredClone(v))}},getWebSockets(){return sockets}};
  const room=new GameRoom(context,{});
  const makeSocket=id=>{const ws={id,messages:[],deserializeAttachment(){return{id}},send(message){this.messages.push(JSON.parse(message))}};sockets.push(ws);room.sessions.set(id,ws);return ws};
  return {room,makeSocket,store};
}
const action=(room,ws,kind,more={})=>room.webSocketMessage(ws,JSON.stringify({type:'action',kind,...more}));

test('secret answers remain private until both players answer',async()=>{
 const {room,makeSocket}=fixture();await room.ready;
 const a=makeSocket('a'),b=makeSocket('b');room.state.players=[{id:'a',name:'A'},{id:'b',name:'B'}];
 await action(room,a,'same',{choice:'beach'});
 assert.deepEqual(room.forPlayer('b').same.answers,{});
 assert.equal(room.forPlayer('a').same.answers.a,'beach');
 await action(room,b,'same',{choice:'mountains'});
 assert(room.state.completed.includes('same'));
 assert.deepEqual(room.forPlayer('b').same.answers,{a:'beach',b:'mountains'});
});

test('signal guide alternates on replay and codes regenerate',async()=>{
 const {room,makeSocket}=fixture();await room.ready;
 const a=makeSocket('a'),b=makeSocket('b');room.state.players=[{id:'a'},{id:'b'}];
 const first=room.state.clues.sequence.join('');
 assert.equal(room.forPlayer('b').clues.sequence.length,0);
 await action(room,a,'clues',{answer:first});
 assert.equal(room.state.completed.includes('clues'),false);
 await action(room,b,'clues',{answer:first});
 assert.equal(room.state.completed.includes('clues'),true);
 await action(room,a,'reset',{game:'clues'});
 assert.equal(room.state.clues.round,1);
 assert.equal(room.forPlayer('a').clues.sequence.length,0);
 assert.equal(room.forPlayer('b').clues.sequence.length,4);
 const second=room.state.clues.sequence.join('');
 await action(room,b,'clues',{answer:second});
 assert.equal(room.state.completed.includes('clues'),false);
 await action(room,a,'clues',{answer:second});
 assert(room.state.completed.includes('clues'));
});

test('single player cannot complete multiplayer challenges',async()=>{
 const {room,makeSocket}=fixture();await room.ready;
 const a=makeSocket('a');room.state.players=[{id:'a'}];
 await action(room,a,'same',{choice:'beach'});
 await action(room,a,'clues',{answer:room.state.clues.sequence.join('')});
 await action(room,a,'switch');
 assert.deepEqual(room.state.completed,[]);
});

test('movement is bounded and unreasonable jumps are capped',async()=>{
 const {room,makeSocket}=fixture();await room.ready;
 const a=makeSocket('a');room.state.players=[{id:'a',x:.35,y:.53}];
 await action(room,a,'move',{x:.87,y:.78});
 assert(room.state.players[0].x<.6);
 assert(room.state.players[0].y<.7);
});
