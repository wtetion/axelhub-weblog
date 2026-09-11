# Axel Hub Web Log — GitHub + Cloudflare Workers

This repository is prepared for GitHub. The web UI is served from Cloudflare Workers Static Assets, the API runs in the Worker, and data uses Cloudflare D1.

## Deploy from a PC

1. Install Node.js LTS.
2. Run `npm install`.
3. Run `npx wrangler login`.
4. Set the D1 `database_id` in `wrangler.jsonc` (or use the included setup script to create/find the D1 database).
5. Run `npm run db:migrate:remote`.
6. Run `npm run deploy`.

Do not use the Cloudflare Dashboard "Upload and deploy" uploader for this repository; use Wrangler because the project contains `wrangler.jsonc`, a Worker, Static Assets, and D1 bindings.

## Deploy from GitHub Actions

The workflow in `.github/workflows/deploy-cloudflare.yml` deploys with Wrangler. Add these GitHub repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

The API token should have the permissions required to deploy Workers and manage the D1 resource used by this project.

## Static files

Static files are in `public/` and are configured in `wrangler.jsonc`:

```json
"assets": {
  "directory": "./public/",
  "binding": "ASSETS"
}
```

## Secrets

Never commit real Cloudflare tokens, API keys, passwords, `.env`, or production user data to GitHub. Use GitHub Secrets / Cloudflare secrets instead.
