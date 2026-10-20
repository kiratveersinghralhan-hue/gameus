# Phase 9 · Islands Journey (first playable expansion)

This package is based on Phase 8. **Deploy Phase 8 SQL first** if you have not yet done so.

1. Back up your current `D:\Development\BetweenUS` repository. Extract this archive to a temporary folder.
2. **Do not overwrite** `docs/config.js`, `public/config.js`, `.git`, or your `.env` files. Copy everything else into the active repository.
3. In Supabase SQL Editor run `202610200003_phase8_challenges.sql` if missing, then `202610200004_island_journey.sql`. The second migration updates the existing `bu_turn` RPC; do NOT rerun old initial schema.
4. From your active repository: `npm test`, then `git add docs public tests supabase/migrations PHASE-9-DEPLOY.md`, `git commit -m "Add Mirror Forest island journey"`, `git push origin main`.
5. Hard-refresh GitHub Pages. **Create a new room** (do not reuse old rooms for this schema change). Finish the four Heartlight puzzles together, click **Travel to Mirror Forest**, then play **Reflecting Path** with two separate browsers.

Phase 9 includes one second-island challenge and a persisted shared island selection. It is not an endless procedural engine yet. Existing rooms created before the migration may lack `mirror` initial state; create a new room for reliable testing. Live cross-device testing has not been performed here.
