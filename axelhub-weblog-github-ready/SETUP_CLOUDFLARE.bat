@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP_CLOUDFLARE.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed. Read the error above.
  pause
  exit /b 1
)
echo.
echo Setup finished.
pause
