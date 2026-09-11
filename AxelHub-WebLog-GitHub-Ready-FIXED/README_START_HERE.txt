AXEL HUB WEBLOG - START HERE

EASIEST METHOD (Windows)
1. Extract the ZIP.
2. Install Node.js LTS.
3. Double-click SETUP_CLOUDFLARE.bat.

MANUAL METHOD
1. cd into this folder
2. npm install
3. npx wrangler login
4. npx wrangler d1 create axelhub-weblog
5. Put the returned database_id into wrangler.jsonc
6. npx wrangler secret put AUTH_SECRET
7. npx wrangler d1 migrations apply axelhub-weblog --remote
8. npx wrangler deploy

The Worker will publish the WebLog UI and API from the same *.workers.dev URL.
