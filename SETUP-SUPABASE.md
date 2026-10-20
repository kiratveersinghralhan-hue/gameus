# Make BETWEEN US play online (Mac + Windows)

This release preserves `https://kiratveersinghralhan-hue.github.io/gameus/` and its offline two-tab demo. GitHub Pages cannot run a multiplayer backend: the backend below is **Supabase**. No service-role credentials belong in GitHub.

## 1 — Create a Supabase project

1. Create a project at https://supabase.com/dashboard (Free plan). Choose a secure database password and region close to your players.
2. Project dashboard → **Authentication → Providers → Anonymous Sign-ins** → enable anonymous authentication. This is mandatory for the no-account join experience.
3. In your project **SQL Editor**, paste the entire contents of `supabase/migrations/202610200001_game.sql`, then Run. Only do this once. It creates room tables, row security and server-owned game commands.
4. Under **Project Settings → API** (or **Connect**, depending on dashboard version), copy the project URL and its **anon/publishable key**. **NEVER** copy the `service_role` or secret key to GitHub or any frontend file.

## 2 — Deploy the Edge Function

With Node.js installed on your Windows PC, open a terminal in the extracted project folder:

```sh
npm install
npx supabase login
npx supabase link --project-ref YOUR_SUPABASE_PROJECT_REF
npx supabase functions deploy game-api --no-verify-jwt
```

The Edge Function is at `supabase/functions/game-api/index.ts`. `--no-verify-jwt` is used because this function verifies the caller's actual Supabase user token using `auth.getUser()` internally (required for some publishable-key environments). Do not remove that server verification. Supabase automatically exposes the project URL and server secrets to hosted Edge Functions. If the function reports missing environment variables, inspect Supabase's function secret configuration; do **not** paste server secrets in public files.

If the Supabase CLI requires a local development toolchain, follow its CLI installation guidance. If you cannot deploy, the local two-tab mode still works.

## 3 — Configure the GitHub Pages frontend

Edit **both** `docs/config.js` and `public/config.js` (or edit public and copy it into docs):

```js
window.BETWEEN_US_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseAnonKey: 'YOUR_BROWSER_PUBLISHABLE_OR_ANON_KEY',
};
```

Only these **public** values go into client JavaScript. Commit the repository files to `main`. Ensure **GitHub Settings → Pages → Deploy from branch → main → /docs**. Wait until Actions shows deployment complete. Refresh with Ctrl+Shift+R.

## 4 — Play and verify

1. Visit `https://kiratveersinghralhan-hue.github.io/gameus/` in Chrome on Windows.
2. Enter a nickname and **Create a world**. Confirm the status says **Connected**.
3. Click **Copy invite** and send the **complete URL** to your friend on Mac Safari or Chrome. The link includes an unguessable secret; treat it as private.
4. She enters her nickname and clicks **Join a friend**, then confirms her pasted invitation if needed.
5. Both explorers appear. Test Same Brain: **one person submits**, verify the other **cannot see their answer** until both submit.
6. Test Lost Signals: the guide sees the four symbols, the decoder sees the buttons. Test Memory Garden, Two Lights, replay and disconnect/rejoin.
7. If joining fails: verify anonymous sign-in, the Edge Function deployment, project URL/key and SQL migration. Open browser Developer Tools → Console/Network for errors.

### Important limits and realistic status

* This ZIP contains the full implementation, but has **not** been deployed to your Supabase account and **has not** passed a real two-device session yet. The next validation must be performed using your project credentials in your account.
* Anonymous player accounts are stored in browser storage. Clearing browser data creates a new identity; it cannot reclaim an occupied slot from an old identity yet. A future release should add signed resume tokens and stale-session recovery.
* Realtime movement is visual and client-broadcast (bounded coordinates), while mini-game outcomes are authoritative in PostgreSQL. This is suitable for cooperative play, not cheat-resistant competitive play.
* Free plan has quotas (and projects may pause after inactivity). Public launch needs monitoring, cleanup, abuse protection, rate limits and a load test. This prototype does **not** guarantee capacity for unlimited public concurrent players.
* The invite secret appears in the URL, so do not share screenshots of the complete URL or post it publicly. The demo URL is different and only connects browser tabs on the same origin/device.
* Backend room records are persistent until cleaned; do not store personal secrets in question answers. A lifecycle cleanup script is required before public launch.

## Files

- `docs/` — live GitHub Pages website
- `public/` — same client used with Cloudflare Worker if you want that fallback
- `supabase/migrations/` — server SQL, room policies and authoritative rule engine
- `supabase/functions/game-api/` — auth-verifying Edge Function
- `worker/` — legacy Cloudflare backend retained for compatibility, **not used by GitHub Pages with Supabase configured**
- `tests/` — old Cloudflare room unit tests and new package checks
