@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-registry-image.ps1" %*
