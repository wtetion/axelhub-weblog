# Axel Hub Web Log — GitHub + always-on deployment

## What this build does

- `http://127.0.0.1:3000` is the configured public Web Log URL.
- Visitors see a Sign in page first, with a separate Sign up page.
- Passwords are **not stored in plaintext**. `data/users.xlsx` stores a salted `scrypt` password hash plus a per-user telemetry key.
- Every web user has a separate data namespace. User A cannot read User B's accounts, events, inventory, analytics, or graph through the dashboard APIs.
- Roblox/Luau telemetry is isolated by the personal telemetry key shown after signing in.
- The Axel Hub logo is served from `/assets/axel-logo.png` with a fallback so the header does not become blank when the image path fails.

## Repository layout

This folder is ready to commit as a GitHub repository. Do not commit real `data/store.json`, `data/users.xlsx`, or production secrets after users have registered. Keep production data on the server's persistent data volume.

## Environment variables

- `PUBLIC_BASE_URL=http://127.0.0.1:3000`
- `AUTH_SECRET=<long random secret>`
- `DATA_DIR=/var/data`
- `AXEL_API_KEY=<optional legacy local fallback; not used by normal signed-up users>`

## Deploying from GitHub

GitHub stores the source; it does not itself run an Express server continuously. Connect this repository to a Node web-service host and point `localhost:3000` to that service. `render.yaml` is included for a GitHub-connected Render Web Service, with a persistent disk mounted at `/var/data`.

After deployment, configure the custom domain `localhost:3000` in the hosting provider and use the HTTPS URL as the Luau `WEBLOG_URL`.

## First use

1. Open `http://127.0.0.1:3000`.
2. Create a Web Log account.
3. Copy the personal **Telemetry Key** shown in the dashboard.
4. Put that key in `WEBLOG_API_KEY` in the Luau script.
5. Keep `WEBLOG_URL` set to `http://127.0.0.1:3000/api/telemetry`.

Each Web Log username gets a unique telemetry key and private dashboard namespace.

## Important persistence note

The realtime game data stays in `data/store.json` and credentials stay in `data/users.xlsx`. A host with an ephemeral filesystem can lose those files on restart/redeploy, so production must use persistent storage or a managed database. The included Render configuration uses a persistent disk at `/var/data`.
