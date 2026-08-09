@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\Start-CoAAddonManager.ps1"
if errorlevel 1 (
  echo.
  if "%COA_NONINTERACTIVE%"=="1" exit /b 1
  pause
)
