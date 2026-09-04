@echo off
setlocal
rem Launch the project without changing the machine or user execution policy.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_game.ps1"
if errorlevel 1 pause
endlocal
