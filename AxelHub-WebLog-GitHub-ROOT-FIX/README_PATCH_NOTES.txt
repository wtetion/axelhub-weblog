AXEL HUB - PATCH NOTES

1) TELEMETRY TOKEN UI
- Added a large, mobile-friendly Telemetry Token card.
- Added COPY TOKEN button with Clipboard API + textarea fallback.
- Added desktop top-bar COPY KEY button.
- Token text is larger and selectable for easy copy on PC and mobile.
- Private Web Log URL remains visible below the token.

2) RETURN-TO-BASE TREADMILL BYPASS
- Added dynamic treadmill position detection from the current plot.
- Return routes check the actual treadmill position in X/Z space.
- If the return segment would pass too close to the treadmill, a dynamic bypass waypoint is inserted.
- Applied to Tween Glide, Fly Glide and Safe Walk return paths.
- Also checks the final return-to-base segment before entering the base pen.

3) AUTH UI
- Sign in / Sign up continue using the Axel Hub glassmorphism design already included in the supplied project.

Files changed:
- public/index.html
- public/style.css
- public/app.js
- Steal_WebLog_Connected.luau
