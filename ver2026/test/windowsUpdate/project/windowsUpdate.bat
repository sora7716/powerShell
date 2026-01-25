@echo off
echo %~dp0windowsUpdate.ps1
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0windowsUpdate.ps1"
pause
