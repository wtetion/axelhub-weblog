@echo off
setlocal
cd /d "%~dp0"

echo.
echo ================================================
echo   AXEL HUB WEBLOG - CLOUDFLARE ONE CLICK
echo ================================================
echo.
echo Opening Cloudflare and starting automatic setup...
echo.

start "" "https://dash.cloudflare.com/"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP_CLOUDFLARE.ps1"
set "ERR=%ERRORLEVEL%"

echo.
if not "%ERR%"=="0" (
  echo ================================================
  echo Setup/deployment failed. Read the error above.
  echo ================================================
  pause
  exit /b %ERR%
)

echo ================================================
echo Deployment complete.
echo Cloudflare / Worker browser tabs were opened automatically.
echo ================================================
echo.
pause
