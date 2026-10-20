# BETWEEN US — Fixed GitHub Pages release

## GitHub Pages (free browser demo)

This repository has been arranged to fix GitHub Pages 404 at `/gameus/`.

1. Upload the **contents of this folder** to the root of your `gameus` GitHub repository (not the ZIP itself and not an extra `gameus-main/` folder).
2. GitHub → Settings → Pages → Build and deployment → Deploy from a branch → `main` → `/docs` → Save.
3. Wait for the successful Pages deployment, then visit `https://kiratveersinghralhan-hue.github.io/gameus/`.
4. Click **Try the local two-tab demo**, copy the invite and open it in a second tab on the same computer. The local demo uses browser local storage and BroadcastChannel; it **cannot connect two separate computers**.

**Important:** GitHub Pages hosts static files only. It does not execute the multiplayer `worker/` backend. The **Create a world** and **Join a friend** live multiplayer options are intentionally blocked on GitHub Pages instead of silently failing.

## Real multiplayer (Mac ↔ Windows)

The source has a Cloudflare Worker + Durable Object backend. With Node.js installed:

```sh
npm install
npx wrangler login
npm run deploy
```

The deployment uses `wrangler.jsonc`, serving `public/` as the frontend and `worker/index.js` for WebSockets. Both friends must open the resulting `*.workers.dev` HTTPS URL for online multiplayer. Cloudflare account creation, deployment, billing eligibility, and real-device testing are not done by this ZIP. Review deployment errors and your Cloudflare plan before relying on it.

## File guide

- `docs/`: static GitHub Pages version (root-relative URL bug fixed)
- `public/`: Cloudflare Worker website assets
- `worker/`: actual WebSocket multiplayer service
- `tests/`: Node.js logic tests

If Pages still reports 404, check **Actions** for Pages deployment success, ensure branch is `main`, folder is `/docs`, and that `docs/index.html` is present on that branch.

## Checks performed

`node --test tests/room.test.js` passed 4/4 and JS syntax checks passed. Real browser and deployed Cloudflare multiplayer are **not yet verified**.
