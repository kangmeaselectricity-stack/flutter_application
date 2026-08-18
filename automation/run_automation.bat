@echo off
chcp 65001 > nul
title E-POWER Auto-Sync Automation Tool Launcher

echo ========================================================
echo   ⚡ E-POWER Billing Auto-Sync Automation Tool Launcher
echo ========================================================
echo.

cd /d "%~dp0"

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set PY_CMD=py
) else (
    set PY_CMD=python
)

echo [1/2] Checking & Installing Python packages...
%PY_CMD% -m pip install -r requirements.txt --quiet --disable-pip-version-check

echo [2/2] Launching E-POWER Automation Tool...
echo.
%PY_CMD% epower_auto_sync.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Program exited. Press any key to exit...
    pause > nul
)
