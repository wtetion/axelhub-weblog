# AxelHub WebLog — Cloudflare Workers + D1

## Fastest setup on Windows

1. Install Node.js LTS.
2. Extract this project.
3. Double-click `DEPLOY_NOW.bat`.
4. Cloudflare Dashboard opens automatically.
5. Wrangler opens the current Cloudflare Device Authorization login automatically; approve it once.
6. The script finds/creates D1, generates `AUTH_SECRET`, applies remote migrations, deploys, and opens the Worker URL + health check automatically.

Cloudflare account approval is intentionally the only manual security step.

## Manual setup

```powershell
npm install
npx wrangler login
npx wrangler d1 create axelhub-weblog
# put returned database_id into wrangler.jsonc
npx wrangler secret put AUTH_SECRET
npx wrangler d1 migrations apply axelhub-weblog --remote
npx wrangler deploy
```

## Endpoints

- `/` — Login or dashboard
- `/api/health` — health check
- `/api/auth/signup` — sign up
- `/api/auth/login` — sign in
- `/api/auth/logout` — sign out
- `/api/auth/me` — current session
- `/api/telemetry` — telemetry ingest
- `/api/accounts` — private accounts for logged-in user
- `/api/analytics` — private analytics for logged-in user
- `/api/graph` — private graph data
- `/api/events` — private event log

## Luau config

```lua
getgenv().AxelWebLogConfig = {
    Enabled = true,
    URL = "https://YOUR-WORKER.workers.dev/api/telemetry",
    Key = "axel_YOUR_PERSONAL_TELEMETRY_KEY",
    Interval = 5,
    Debug = false,
    LocalFallback = true,
}
```

Use the same URL for every user. Each user gets a different telemetry Key.
