import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const file=x=>readFileSync(new URL('../'+x,import.meta.url),'utf8');
test('GitHub Pages files are self-contained and support anonymous online play',()=>{
  assert.match(file('docs/index.html'),/src="\.\/config\.js"/);
  assert.match(file('docs/index.html'),/src="\.\/app\.js"/);
  assert.match(file('docs/index.html'),/Paste the full invitation link/);
  assert.equal(file('docs/app.js'),file('public/app.js'));
  assert.equal(file('docs/supabase-client.js'),file('public/supabase-client.js'));
  assert.equal(file('docs/config.js'),file('public/config.js'));
  assert.match(file('docs/app.js'),/connectSupabase/);
});
test('browser configuration never ships service credentials',()=>{
  assert.doesNotMatch(file('docs/config.js'),/service_role|sk_test_|sb_secret_/i);
  assert.match(file('supabase/functions/game-api/index.ts'),/auth\.getUser/);
  assert.match(file('supabase/migrations/202610200001_game.sql'),/row level security/);
  assert.match(file('supabase/migrations/202610200001_game.sql'),/only participants receive game refresh events/);
});
