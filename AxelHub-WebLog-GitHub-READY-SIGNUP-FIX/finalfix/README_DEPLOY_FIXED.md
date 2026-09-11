# AxelHub WebLog - Cloudflare deploy fix

This package is prepared for a GitHub repository where `public/`, `src/`, `migrations/`, `wrangler.jsonc`, and `package.json` are directly under the project root.

Cloudflare Workers Builds:
- Root directory: `/` when those folders are at the repository root. If this whole project is inside a subfolder, set Root directory to that exact subfolder instead.
- Build command: leave empty
- Deploy command: `npx wrangler deploy`

D1:
- database_name: `website`
- database_id: `8777522c-00bf-4833-94fc-d343ee1e5c7c`
- binding: `DB`

Before Signup/Login works, create the Worker secret `AUTH_SECRET` in Cloudflare.
