@echo off
rem Double-click launcher for the Windows control panel.
rem Runs dvs-ptp-mitm.ps1 (which elevates via UAC and shows the menu).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dvs-ptp-mitm.ps1"
