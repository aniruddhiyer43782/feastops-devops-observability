@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0expose-public-tunnel.ps1" %*
