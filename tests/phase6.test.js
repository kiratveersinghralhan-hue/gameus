import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
for(const dir of ['docs','public']){
 test(`${dir}: entry, navigation and setup are wired`,()=>{const html=fs.readFileSync(`${dir}/index.html`,'utf8');const js=fs.readFileSync(`${dir}/app.js`,'utf8');assert.match(html,/id="backNav"/);assert.match(html,/id="setupPanel"/);assert.match(js,/testSettings/);assert.match(js,/validOnlineConfig/);assert.match(js,/showLanding/)});
}
