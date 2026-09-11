# Axel Hub Web Log

Private multi-user Roblox/Luau Web Log with account isolation, sign-in/sign-up, per-user telemetry keys, Rarity/Inventory views, graphing, and egg imagery.

## Public URL

Configured public URL: `https://Axelhub.ud0`

## Login / Sign up

The dashboard is protected by a username/password sign-in page. New users create an account first. Passwords are stored as salted `scrypt` hashes inside `data/users.xlsx` rather than plaintext.

Every registered user receives a unique telemetry key. The Luau script sends telemetry with that key, and the server stores the telemetry in that user's private namespace. Dashboard API requests use the signed login session, so one user cannot see another user's data.

## Deployment

The source is GitHub-ready. GitHub is the repository; it is not the runtime for this Express app. Use the included `render.yaml` with a GitHub-connected Render Web Service (or another Node web host) and configure `PUBLIC_BASE_URL=https://Axelhub.ud0`, `AUTH_SECRET`, and persistent `DATA_DIR`. See `README_DEPLOY_GITHUB.md`.

## Luau

Set:

```lua
local WEBLOG_URL = "https://Axelhub.ud0/api/telemetry"
local WEBLOG_API_KEY = "PASTE_YOUR_PERSONAL_TELEMETRY_KEY"
```

The personal key appears in the dashboard after sign-up/sign-in.
