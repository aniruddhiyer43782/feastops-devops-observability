@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-app-image.ps1" %*
