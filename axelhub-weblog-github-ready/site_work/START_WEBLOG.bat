@echo off
setlocal
cd /d "%~dp0"

echo ==============================================
echo          AXEL HUB - WEB LOG
echo ==============================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js is not installed.
  echo Install Node.js 18+ from https://nodejs.org/
  echo.
  pause
  exit /b 1
)

echo [1/3] Checking dependencies...
if not exist "node_modules\express" (
  echo [2/3] Installing dependencies...
  call npm.cmd install
  if errorlevel 1 (
    echo.
    echo [ERROR] npm install failed.
    pause
    exit /b 1
  )
) else (
  echo [2/3] Dependencies already installed.
)

if not exist ".env" (
  echo PORT=3000>".env"
  echo AXEL_API_KEY=AxelSecret123456>>".env"
  echo [INFO] Created .env with a default local API key.
)

echo [3/3] Starting Web Log...
start "Axel Web Log - Browser" https://Axelhub.ud0
call npm.cmd start

pause
endlocal
