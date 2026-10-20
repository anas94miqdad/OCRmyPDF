@echo off
rem SPDX-FileCopyrightText: 2026 Anas Miqdad
rem SPDX-License-Identifier: MPL-2.0
rem Installiert Tesseract, uv, OCRmyPDF und das deutsche Sprachpaket.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installieren.ps1"
echo.
pause
