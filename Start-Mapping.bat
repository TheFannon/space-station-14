@echo off
setlocal
title SS14 StarTrek - Start Mapping
cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
  echo ERROR: PowerShell not found.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Mapping.ps1"
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo.
  echo Launcher failed with exit code %ERR%.
  echo See Start-Mapping.log in this folder.
  pause
)
exit /b %ERR%
