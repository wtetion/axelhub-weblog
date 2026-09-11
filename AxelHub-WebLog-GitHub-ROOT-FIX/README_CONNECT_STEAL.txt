AXEL WEB LOG CONNECTION

Set the Luau endpoint to http://127.0.0.1:3000/api/telemetry.
Use the personal Telemetry Key shown after signing in.
Telemetry is isolated by that key, so different Web Log users do not share account data.


LOCAL CONNECTION FIX
1. Sign in to the Web Log.
2. Copy your personal Telemetry Key.
3. Before running the script, set:
   getgenv().AXEL_WEBLOG_URL = "http://127.0.0.1:3000/api/telemetry"
   getgenv().AXEL_WEBLOG_KEY = "YOUR_PERSONAL_KEY"
The script falls back to localhost when the public URL cannot be reached.
