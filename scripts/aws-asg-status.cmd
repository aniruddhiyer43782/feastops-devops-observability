@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0aws-asg-status.ps1" %*
