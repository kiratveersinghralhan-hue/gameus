import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const get=x=>readFileSync(new URL('../'+x,import.meta.url),'utf8');
test('play together UI supports Mac invite and two-player readiness',()=>{const html=get('docs/index.html'),js=get('docs/app.js');for(const name of ['playTogether','togetherPanel','togetherCopy','togetherCheck','togetherReadiness'])assert.match(html,new RegExp('id=\"'+name+'\"'));assert.match(js,/function updateTogether/);assert.match(js,/function copyPrivateInvite/);assert.match(js,/closeTogether\(\)/)});
test('browser page does not store private invitation key as part of analytics',()=>{const js=get('docs/app.js');assert.doesNotMatch(js,/gtag\(|analytics\.track\(/)});
