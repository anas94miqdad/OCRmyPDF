@echo off
rem SPDX-FileCopyrightText: 2026 Anas Miqdad
rem SPDX-License-Identifier: MPL-2.0
rem Wie "OCR starten.bat", aber mit Einstellungen fuer Handyfotos und unscharfe Scans.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ocr-ordner.ps1" -Foto %*
echo.
pause
