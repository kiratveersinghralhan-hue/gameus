# BETWEEN US Phase 6 — online rooms + back navigation

This package keeps the existing 4 adventures and GitHub Pages `docs/` output.

## What changed
- Visible Back button in the top bar: closes dialogs and can return to the main menu.
- Supabase configuration diagnostics right on the landing screen.
- If online settings are missing, Create a world opens setup rather than leaving you in a broken empty island.
- Setup runs an actual anonymous sign-in test before you attempt multiplayer.
- Clear online-room creation status and invite instructions inside the game.
- The local two-tab demo is clearly labeled as local-only.

## Publish
1. Keep/copy your configured `docs/config.js` and `public/config.js` from the currently working repository into this extracted package **before uploading**. The ZIP contains placeholder keys because secrets were never supplied here.
2. Upload the extracted package contents (including `docs/index.html`, `docs/app.js`, `docs/style.css`) to your GitHub repository `gameus` on `main`; Pages source stays `main /docs`.
3. Hard-refresh https://kiratveersinghralhan-hue.github.io/gameus/ .
4. If the landing screen says Supabase settings missing, press **Online multiplayer setup / diagnose**, enter project URL `https://acmxtpjgugbpvbduatzq.supabase.co` and your **publishable/anon** public key, then **Test connection**. Do not paste a service-role key.
5. If login succeeds, click **Create a world**. Wait for “Online room created!” and then **Copy invite**.
6. Send the invitation URL to your friend. She should open the link on her Mac, enter a nickname, and click **Join room**. Both should see `2 of 2 explorers here` when presence is connected.
7. If room creation fails, look at the on-screen error, Supabase > Edge Functions > game-api > Logs, verify anonymous sign-in is enabled in Authentication > Providers, and ensure migration `202610200001_game.sql` has run in SQL Editor. CLI function `game-api` ACTIVE alone is not proof all these services work.

### Important
- Saving the public key in the setup screen affects **only your own browser**. For your friend to play, place that public key in `docs/config.js` and publish that updated file to GitHub. Public publishable/anon keys are intended for browsers, unlike service_role/secret keys.
- GitHub Pages still hosts only static assets; Supabase handles online multiplayer.
- Browser/Cross-device testing was not executed in this environment; code validation and local automated tests are not equivalent to live online testing.
