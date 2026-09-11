AXEL HUB WEBLOG - ONE CLICK CLOUDFLARE PACKAGE

WHAT THIS PACKAGE CONTAINS
- Cloudflare Worker API
- D1 private database schema
- Premium WebLog UI + Login / Sign up
- EN / Thai UI
- Private telemetry per user
- Telemetry key support
- Latest Luau script
- Auto Steal / Auto Treadmill reset build from the combined project

IMPORTANT
Do NOT drag this project into Cloudflare's "Upload and deploy" uploader.
That page is for static upload projects and will reject Wrangler-based projects like this one.

EASIEST DEPLOY
1. Install Node.js LTS.
2. Extract this ZIP.
3. Double-click DEPLOY_NOW.bat.
4. Sign in to Cloudflare in the browser when Wrangler asks.
5. The script creates/uses D1, applies migrations, sets AUTH_SECRET, and deploys the Worker.
6. Copy the *.workers.dev URL shown at the end.

MANUAL DEPLOY
npx wrangler login
npx wrangler d1 create axelhub-weblog
npx wrangler d1 migrations apply axelhub-weblog --remote
npx wrangler deploy

AFTER DEPLOY
Web:    https://<worker>.workers.dev/
Health: https://<worker>.workers.dev/api/health
API:    https://<worker>.workers.dev/api/telemetry

LUACONFIG
getgenv().AxelWebLogConfig = {
    Enabled = true,
    URL = "https://<worker>.workers.dev/api/telemetry",
    Key = "axel_your_personal_key",
    Interval = 5,
    Debug = false,
    LocalFallback = true,
}

All users share the same URL. Only the personal telemetry Key differs.
