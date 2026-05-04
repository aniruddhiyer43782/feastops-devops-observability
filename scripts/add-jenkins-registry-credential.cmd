@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-jenkins-registry-credential.ps1" %*
