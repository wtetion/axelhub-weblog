@echo off
setlocal
cd /d "%~dp0"
if not exist package.json (
  echo package.json not found.
  pause
  exit /b 1
)
where node >nul 2>nul || (
  echo Node.js is not installed.
  pause
  exit /b 1
)
echo Checking Worker JavaScript syntax...
node --check src\index.js
if errorlevel 1 (
  echo Syntax check failed.
  pause
  exit /b 1
)
echo Syntax check passed.
pause
