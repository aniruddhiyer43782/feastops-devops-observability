@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scale-kubernetes.ps1" %*
