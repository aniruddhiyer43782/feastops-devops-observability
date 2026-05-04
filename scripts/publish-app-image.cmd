@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish-app-image.ps1" %*
