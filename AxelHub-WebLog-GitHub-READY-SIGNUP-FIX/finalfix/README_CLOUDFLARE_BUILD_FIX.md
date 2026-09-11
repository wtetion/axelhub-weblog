# Cloudflare Workers Builds fix

This repository deploys with Cloudflare Workers + Static Assets + D1.

In Cloudflare Workers Builds, set the Root directory to the repository root (the folder containing `wrangler.jsonc`, `public/`, and `src/`).

Use this Deploy command:

```bash
npx wrangler deploy --assets ./public
```

The explicit `--assets ./public` avoids static-asset directory auto-detection failures in Workers Builds. Cloudflare documents this form for deploying a Worker together with static assets.

If `wrangler.jsonc` still contains `PASTE_YOUR_D1_DATABASE_ID_HERE`, replace it with the real D1 database ID before deployment, or create/bind the D1 database first.
