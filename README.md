# BETWEEN US — A world built for two

A browser-playable two-player atmospheric island adventure with real multiplayer rooms, secret choices, collaborative puzzles and shareable invitations. Runs on macOS/Windows in modern Chrome, Edge and Safari. Zero third-party frontend dependencies. The canvas environment is **2.5D** (not a full Three.js world yet).

## What's actually playable
- Premium responsive landing screen and illustrated 2.5D world with animated stars, avatars and portals.
- Two players via private invitation URL and room code display.
- Live synchronized movement, player presence and reconnection to the same player slot.
- `Same Brain`: secret choice, synchronized result reveal; six rotating prompts on replay.
- `Lost Signals`: asymmetric randomized four-symbol sequence; player roles alternate each replay.
- `Two Lights`: both explorers activate separate beacons.
- Reward fragments, 3/3 progress and replay.
- Optional Memory Garden with eight conversation prompts; no personal answers are saved.
- Mobile touch controls, keyboard WASD / arrow keys / E.
- Local two-tab demo through BroadcastChannel and localStorage.

## Try it now (no cloud account)

On Windows you can double-click `start-local-windows.bat` (Python required). On Mac you can run `start-local-mac.command` (Python 3 required). Alternatively, from the project directory run:

```sh
python3 -m http.server 8080 --directory public
```

Visit `http://localhost:8080/`, enter a nickname and click **Try the local two-tab demo**. Copy the invite link. Open that link in a **second tab in the same browser**, choose a **different nickname**, and click **Join room**. Both tabs will now communicate using local storage and BroadcastChannel. The demo does **not** connect separate devices and is only for testing on one browser profile. To test truly separate players, use an incognito window with an independent session but same origin storage may differ; normal tabs are simplest.

## Deploy live multiplayer on Cloudflare Workers

Requires a Cloudflare account; check Cloudflare pricing and free-tier limits before deploying.

1. Install Node.js 20.19+ or 22+.
2. In the project folder run `npm install`.
3. Run `npx wrangler login` to authenticate **in your own terminal**.
4. Run `npm run deploy`.
5. Open the published `https://...workers.dev` URL on Windows.
6. Enter your nickname and choose **Create a world**.
7. Use **Copy invite** and send the complete URL to your friend on Mac.
8. She opens the link, chooses her nickname and clicks **Join room**.

Development with the real server: `npm run dev` then open the localhost URL Wrangler prints. The generated Worker endpoint is `/api/room/:roomCode` and relies on WebSockets.

**Security:** the 10-character room ID is only an identifier. The actual authorization capability is a separate 192-bit random invite token embedded in the private invitation link. Don't post it publicly. The server limits rooms to 2 slots, validates message inputs, and only sends a player's own secret choice prior to a reveal; only the guide sees puzzle symbols. This is a casual-game security baseline, *not* a professional penetration-tested deployment. Room data persists in Durable Object storage; there is no expiration policy in this first release.

**Known limitations**: two active player slots are retained for reconnection; there is no kick/reset room management or slot handoff. You can create a new room instead. The collaboration game is intentionally compact; movement collision, audio soundtrack, matchmaking, voice chat, accounts, and 3D models aren't implemented. Live cross-device behavior requires deployment and hasn't been confirmed against a real cloud deployment in this environment. Local mode does not enforce server security.

## Code map
- `public/index.html` — screens and adventure controls
- `public/style.css` — layout, brand identity and responsive UI
- `public/app.js` — interactive canvas renderer, input, gameplay and network client
- `worker/index.js` — Cloudflare Worker + Durable Object room and game authority
- `wrangler.jsonc` — Cloudflare Worker runtime configuration

## Expansion plan
1. Test gameplay with both players in two tabs and fix issues.
2. Validate real room synchronization after Cloudflare deployment.
3. Expand randomized puzzle content and add new question packs.
4. Add avatar collisions and actual world navigation gates.
5. Introduce Three.js visuals only if desktop/Mac tests justify the additional GPU cost.
6. Add accessibility, reduced motion, room expiration, owner reset, reconnect tokens, and room-level telemetry with consent.

## Version 0.2 improvements
- Six replayable question prompts in Same Brain, randomized signal codes, alternating decoder roles.
- Local two-tab reducer aligned to remote game rules; stricter room invite validation.
- Basic backend message rate controls and bounded movement updates.
- Fixed copy-invitation feedback so it does not falsely report success.

For browser testing, use two ordinary tabs, **not** a second tab opened from a duplicate browser session that may clone sessionStorage credentials.
