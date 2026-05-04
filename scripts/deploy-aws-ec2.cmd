@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-aws-ec2.ps1" %*
