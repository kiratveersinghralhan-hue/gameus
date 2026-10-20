import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const get=x=>readFileSync(new URL('../'+x,import.meta.url),'utf8');
test('docs and public browser clients match',()=>{for(const name of ['app.js','config.js','supabase-client.js','index.html','style.css'])assert.equal(get('public/'+name),get('docs/'+name),name)});
test('browser reconnect refresh cleans up listeners',()=>{const s=get('docs/supabase-client.js');assert.match(s,/visibilitychange/);assert.match(s,/removeEventListener\('visibilitychange'/);assert.match(s,/window\.addEventListener\('online'/);});
test('expiry cleanup cannot be executed anonymously',()=>{const s=get('supabase/migrations/202610200002_room_lifecycle.sql');assert.match(s,/revoke all on function public\.bu_cleanup_expired\(\) from public, anon, authenticated/);assert.match(s,/14 days/);});
test('frontend has no deprecated Cloudflare-only instruction and avoids premature copy success',()=>{const s=get('docs/app.js');assert.doesNotMatch(s,/requires the Cloudflare deployment/);assert.match(s,/await navigator\.clipboard\.writeText\(v\)/);assert.match(s,/toast\('Private invitation copied!'\)/);});
