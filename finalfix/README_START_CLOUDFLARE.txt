START HERE - CLOUDFLARE ONE-CLICK

1. Extract the ZIP.
2. Double-click DEPLOY_NOW.bat.
3. Cloudflare Dashboard opens automatically.
4. Wrangler installs/updates automatically.
5. Cloudflare login opens automatically in the browser using the current Device Authorization flow.
6. Approve the login once.
7. The script automatically finds or creates the D1 database, generates AUTH_SECRET, applies remote migrations, and deploys the Worker.
8. After deployment, the Worker URL and /api/health are opened automatically.

Important:
- Cloudflare still requires YOU to approve the login in the browser. The script must not bypass Cloudflare account security.
- You no longer need to manually copy/paste AUTH_SECRET.
- Existing D1 database `axelhub-weblog` is reused when detected.
- Do not use Cloudflare Dashboard > Upload and deploy for this Worker + D1 project. Wrangler is the deployment method.

Cloudflare Dashboard:
https://dash.cloudflare.com/

Current Wrangler login supports `--device`, which opens the authorization page and polls for approval without relying on a localhost callback.
