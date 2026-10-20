# BETWEEN US — Phase 7: Play Together

This update adds a visible **Play together · Invite & test** action inside the island room card. It offers invitation copying, friend-join instructions, and room readiness feedback. The Back button and all four original adventures remain available.

## Important: updating your single Git repository

Your active Git checkout should eventually be `D:\Development\BetweenUS`. Until it is consolidated, you have a local source folder and a separate `gameus-repo` clone. Copy the ZIP contents into your **Git clone** before committing, and keep only the current browser publishable key in `docs/config.js` and `public/config.js`. This ZIP ships placeholder configuration, not your keys.

**Safest update:** Back up your configured `docs/config.js` and `public/config.js` first; copy new Phase 7 files into your Git repository; restore both backed-up config files; run `npm test`; inspect `git status`; commit and push. Exclude `node_modules`, `supabase/.temp`, `.env*`, and credentials from Git. Do not delete your existing `config.js` at the repository root until you have reviewed whether it is still used.

No Supabase migration or Edge Function redeploy is required for this frontend-only phase.

## Testing

On PC select Create a world → Play together → Copy private invitation. Share the link privately. On a Mac open it and select Join room. Both sides should see two explorers. Try Same Brain, Lost Signals, Two Lights and Memory Garden. Room created and connected does **not** alone prove that a second device has joined.

Important: If screenshots of the invite URL have been shared publicly, create a fresh room before inviting a friend.
