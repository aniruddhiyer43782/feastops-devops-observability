@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-aws-asg.ps1" %*
