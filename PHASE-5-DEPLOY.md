# BETWEEN US — Phase 5 update guide

**Existing working website:** https://kiratveersinghralhan-hue.github.io/gameus/

1. **Keep your existing configured keys.** This ZIP intentionally leaves `docs/config.js` and `public/config.js` blank rather than embedding your account values. Copy both of your **previous configured** config files into the extracted project *before uploading* (public anon/publishable key only). Never upload any secret or service-role key.
2. Supabase dashboard → SQL Editor → paste and run `supabase/migrations/202610200002_room_lifecycle.sql`. The original phase-4 migration must already exist. This installs a cleanup function; it does **not** schedule it automatically. Until you set up a trusted periodic schedule, run `select * from public.bu_cleanup_expired();` occasionally in the SQL Editor. Rooms inactive over 14 days are deleted; this is irreversible.
3. Phase 5 changes only browser source and database migration: the already-deployed `game-api` Edge Function remains compatible; redeploy is not required. If you have edited the Edge Function since Phase 4, keep your deployed copy.
4. Upload ZIP **contents** to `main` on GitHub; Pages source remains `main /docs`. Updating changed files is enough. Verify both `docs/config.js` and `public/config.js` are configured before committing.
5. Force refresh Ctrl+Shift+R, create online room, join from a separate device. Test both answers, sleep/wake a laptop, check join/leave, and confirm local demo still works.

## What changed
- Returning from a background tab resynchronizes authoritative puzzle state; network restoration triggers refresh.
- Removed misleading Cloudflare deployment wording from the GitHub Pages client.
- Fixed invitation clipboard feedback so it no longer reports a copy before completion.
- Added room/event expiration migration; included a safe manual cleanup command.
- Added automated browser-client consistency and lifecycle checks.

## Limits before public release
- This is **not** a fully verified public launch. No access to your Supabase project or real-device end-to-end test has been completed here.
- Signed-in anonymous accounts can still occupy both slots even when abandoned. Account reclamation, rate limiting and authenticated Realtime broadcast authorization are future work; do not market as abuse-resistant.
- Realtime movement is cosmetic and not server-authoritative. Do not use it to assign valuable rewards.
- Cleanup must be scheduled by you; deploying SQL does not run it automatically.
