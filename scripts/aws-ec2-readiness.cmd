@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0aws-ec2-readiness.ps1" %*
