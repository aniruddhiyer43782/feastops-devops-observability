@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0aws-devops-stack-status.ps1" %*
