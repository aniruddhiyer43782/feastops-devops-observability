@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-github-webhook.ps1" %*
