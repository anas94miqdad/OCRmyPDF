@echo off
rem SPDX-FileCopyrightText: 2026 Anas Miqdad
rem SPDX-License-Identifier: MPL-2.0
rem Wandelt alle PDFs/Bilder im Ordner "Eingang" in durchsuchbare PDFs um.
rem Dateien oder Ordner koennen auch per Drag & Drop auf diese Datei gezogen werden.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ocr-ordner.ps1" %*
echo.
pause
