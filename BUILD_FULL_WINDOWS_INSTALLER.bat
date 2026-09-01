@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\build_full_windows_installer.ps1"
if errorlevel 1 (
  echo.
  echo BUILD FAILED. Read the error shown above.
  pause
  exit /b 1
)
echo.
echo BUILD COMPLETE.
pause
