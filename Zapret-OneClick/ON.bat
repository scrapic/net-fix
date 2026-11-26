@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ==========================================
echo   Turning ON: DNS-over-HTTPS + hosts + zapret
echo ==========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

echo.
echo ---------------- log ----------------
if exist "%~dp0install.log" type "%~dp0install.log"
echo --------------------------------------
echo.
echo  DONE. Internet bypass is ON.
echo  Press any key to close.
pause >nul