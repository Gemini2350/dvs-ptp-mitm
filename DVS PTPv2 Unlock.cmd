@echo off
rem Double-click launcher for the Windows control panel.
rem Runs dvs-ptpv2-unlock.ps1 (which elevates via UAC and shows the menu).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dvs-ptpv2-unlock.ps1"
