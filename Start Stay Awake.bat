@echo off
rem Opens the Stay Awake window. Double-click this file.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Stay Awake.ps1"
