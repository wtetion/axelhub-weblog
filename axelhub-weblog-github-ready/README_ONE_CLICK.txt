AXEL HUB WEBLOG - ONE CLICK CLOUDFLARE SETUP

1) Extract this ZIP.
2) Install Node.js LTS if needed.
3) Double-click SETUP_CLOUDFLARE.bat.
4) Complete the Cloudflare browser login when it opens.
5) The script will install Wrangler, create/use the D1 database, set AUTH_SECRET,
   apply migrations, and deploy the Worker.
6) Copy the *.workers.dev URL printed by Wrangler.

The Roblox/Luau config should use:

getgenv().AxelWebLogConfig = {
    Enabled = true,
    URL = "https://YOUR-WORKER.workers.dev/api/telemetry",
    Key = "axel_YOUR_PERSONAL_TELEMETRY_KEY",
    Interval = 5,
    Debug = false,
    LocalFallback = true,
}

IMPORTANT
- One shared API URL for everyone.
- Each WebLog account gets its own telemetry Key.
- D1 stores users/telemetry privately by user_id.
- Do NOT share AUTH_SECRET.
