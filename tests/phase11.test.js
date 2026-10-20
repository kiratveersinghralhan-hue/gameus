import {test} from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
for(const root of ['docs','public']){
 test(`${root} has usable tutorial and objective HUD`,()=>{const html=fs.readFileSync(`${root}/index.html`,'utf8');const js=fs.readFileSync(`${root}/app.js`,'utf8');const css=fs.readFileSync(`${root}/style.css`,'utf8');for(const id of ['guidePanel','guideNext','guideClose','objectiveText','guideOpen'])assert.ok(html.includes(`id="${id}"`),id);assert.match(js,/function showGuide\(/);assert.match(js,/function refreshObjective\(/);assert.match(css,/\.guide-overlay/);assert.match(css,/\.objective-bar/)});
 test(`${root} solo preview movement stays client side`,()=>{const js=fs.readFileSync(`${root}/app.js`,'utf8');assert.match(js,/previewIsland\?previewPosition:me\(\)/);assert.match(js,/if\(!previewIsland&&performance\.now\(\)-lastSend>75\)/);assert.match(js,/canvas\.addEventListener\('pointerdown'/)});
}
