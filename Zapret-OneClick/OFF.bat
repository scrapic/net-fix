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
echo   Turning OFF: stops zapret + removes hosts
echo   (DNS-over-HTTPS stays ON, browser keeps working)
echo ==========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0off.ps1"

echo.
echo ---------------- log ----------------
if exist "%~dp0off.log" type "%~dp0off.log"
echo --------------------------------------
echo.
echo  DONE. zapret is OFF.
echo  To fully restore provider DNS too, run:
echo    powershell -ExecutionPolicy Bypass -File "%~dp0off.ps1" -ResetDns
echo  Press any key to close.
pause >nul