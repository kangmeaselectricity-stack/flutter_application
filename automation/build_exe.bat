@echo off
chcp 65001 > nul
title Building E-POWER Automation Tool EXE

echo ========================================================
echo   ⚡ Building E-POWER Auto-Sync Standalone .EXE
echo ========================================================
echo.

cd /d "%~dp0"

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set PY_CMD=py
) else (
    set PY_CMD=python
)

echo [1/2] Checking PyInstaller...
%PY_CMD% -m pip install pyinstaller customtkinter pandas openpyxl pyautogui pyperclip keyboard requests pdfplumber --quiet

echo [2/2] Building executable file...
%PY_CMD% -m PyInstaller --noconfirm --onefile --windowed --name "EPOWER_Auto_Sync" --collect-all customtkinter --clean epower_auto_sync.py

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo ✅ BUILD SUCCESSFUL! 
    echo 📁 File EXE ស្ថិតនៅក្នុង៖ automation\dist\EPOWER_Auto_Sync.exe
    echo ========================================================
) else (
    echo.
    echo ❌ Build failed! Please check error output above.
)

pause
