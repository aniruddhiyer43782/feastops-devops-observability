@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0expose-jenkins-webhook.ps1" %*
