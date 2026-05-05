@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-aws-devops-stack.ps1" %*
