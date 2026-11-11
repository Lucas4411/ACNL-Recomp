@echo off
setlocal
cd /d "%~dp0"
if not exist "ACNL-Launcher.exe" (
  echo ACNL-Launcher.exe nao encontrado nesta pasta.
  pause
  exit /b 1
)
if not exist "game-data" mkdir "game-data"
if not exist "output" mkdir "output"
start "" "%~dp0ACNL-Bootstrap.exe" -Auto
exit /b 0
