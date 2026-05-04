@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-kubernetes.ps1" %*
