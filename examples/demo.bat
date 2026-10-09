@echo off
REM ---------------------------------------------------------------------------
REM demo.bat - CMD entry point.
REM Delegates to demo.ps1, which delegates to demo.sh (the real logic).
REM Keep this file minimal: delegate only, never add logic.
REM ---------------------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0demo.ps1" %*
