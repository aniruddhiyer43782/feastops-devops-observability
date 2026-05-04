@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-jenkins-registry-build.ps1" %*
