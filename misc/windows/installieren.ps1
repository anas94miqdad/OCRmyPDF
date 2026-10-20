# SPDX-FileCopyrightText: 2026 Anas Miqdad
# SPDX-License-Identifier: MPL-2.0

<#
.SYNOPSIS
    Installiert OCRmyPDF mit Tesseract und deutschem Sprachpaket unter Windows.

.DESCRIPTION
    Schritte:
      1. Tesseract (Texterkennung) ueber winget
      2. uv (Python-Paketverwaltung) ueber winget
      3. OCRmyPDF ueber uv
      4. Deutsches Sprachpaket fuer Tesseract, falls es fehlt

    Das Skript wird als normaler Benutzer gestartet. Wo Administratorrechte
    noetig sind, fragt Windows nach (Benutzerkontensteuerung).
    Ghostscript ist optional und wird nicht automatisch installiert.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # macht Downloads in PowerShell 5.1 deutlich schneller
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Sprachpakete, die vorhanden sein sollen (eng und osd bringt Tesseract mit)
$Sprachpakete = @('deu')
$TessdataUrl = 'https://github.com/tesseract-ocr/tessdata/raw/main'

function Write-Schritt([string]$Text) {
    Write-Host ''
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Update-Pfad {
    # PATH neu einlesen, damit frisch installierte Programme gefunden werden
    $maschine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $benutzer = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$maschine;$benutzer;$(Join-Path $env:USERPROFILE '.local\bin')"
}

function Install-WingetPaket([string]$Id, [string]$Name) {
    winget install -e --id $Id --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Installation von $Name ist fehlgeschlagen (Fehlercode $LASTEXITCODE)."
    }
    Update-Pfad
}

function Find-Tesseract {
    $cmd = Get-Command tesseract -ErrorAction SilentlyContinue
    if ($cmd) { return Split-Path -Parent $cmd.Source }
    foreach ($schluessel in @('HKLM:\SOFTWARE\Tesseract-OCR', 'HKCU:\SOFTWARE\Tesseract-OCR')) {
        $eintrag = Get-ItemProperty -Path $schluessel -Name InstallDir -ErrorAction SilentlyContinue
        if ($eintrag -and (Test-Path $eintrag.InstallDir)) { return $eintrag.InstallDir }
    }
    foreach ($ordner in @("$env:ProgramFiles\Tesseract-OCR", "$env:LOCALAPPDATA\Programs\Tesseract-OCR")) {
        if (Test-Path (Join-Path $ordner 'tesseract.exe')) { return $ordner }
    }
    return $null
}

try {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw ('winget wurde nicht gefunden. Bitte den "App-Installer" aus dem Microsoft Store ' +
               'installieren oder die IT um Installation von Tesseract und uv bitten.')
    }

    Write-Schritt 'Tesseract installieren'
    if (Find-Tesseract) {
        Write-Host 'Tesseract ist bereits installiert.'
    } else {
        Install-WingetPaket 'tesseract-ocr.tesseract' 'Tesseract'
    }

    Write-Schritt 'uv installieren'
    Update-Pfad
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host 'uv ist bereits installiert.'
    } else {
        Install-WingetPaket 'astral-sh.uv' 'uv'
    }

    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        throw 'uv wurde nach der Installation nicht gefunden. Bitte ein neues Fenster oeffnen und erneut starten.'
    }

    Write-Schritt 'OCRmyPDF installieren bzw. aktualisieren'
    & $uv.Source tool install ocrmypdf
    if ($LASTEXITCODE -ne 0) { throw "OCRmyPDF konnte nicht installiert werden (Fehlercode $LASTEXITCODE)." }
    & $uv.Source tool upgrade ocrmypdf
    & $uv.Source tool update-shell
    Update-Pfad

    Write-Schritt 'Sprachpakete pruefen'
    $tesseractOrdner = Find-Tesseract
    if (-not $tesseractOrdner) {
        throw 'Tesseract wurde nicht gefunden. Bitte ein neues Fenster oeffnen und erneut starten.'
    }
    $tessdata = Join-Path $tesseractOrdner 'tessdata'
    $fehlend = @($Sprachpakete | Where-Object { -not (Test-Path (Join-Path $tessdata "$_.traineddata")) })

    if ($fehlend.Count -eq 0) {
        Write-Host "Alle Sprachpakete vorhanden ($($Sprachpakete -join ', '))."
    } else {
        $temp = Join-Path $env:TEMP 'ocrmypdf-sprachpakete'
        New-Item -ItemType Directory -Force -Path $temp | Out-Null
        foreach ($sprache in $fehlend) {
            Write-Host "Lade Sprachpaket '$sprache' herunter ..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -UseBasicParsing -Uri "$TessdataUrl/$sprache.traineddata" `
                -OutFile (Join-Path $temp "$sprache.traineddata")
        }
        # Der tessdata-Ordner liegt meist unter "Programme", daher mit Adminrechten kopieren
        Write-Host 'Kopiere Sprachpakete nach Tesseract (Windows fragt nach Administratorrechten) ...'
        $befehl = "Copy-Item -Path '{0}' -Destination '{1}' -Force" -f `
            ((Join-Path $temp '*.traineddata') -replace "'", "''"), ($tessdata -replace "'", "''")
        $kodiert = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($befehl))
        $prozess = Start-Process powershell.exe -Verb RunAs -Wait -PassThru `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $kodiert)
        if ($prozess.ExitCode -ne 0) { throw 'Sprachpakete konnten nicht kopiert werden.' }
        Remove-Item -Recurse -Force $temp
    }

    Write-Schritt 'Pruefung'
    $ocrmypdf = Get-Command ocrmypdf -ErrorAction SilentlyContinue
    if (-not $ocrmypdf) { throw 'ocrmypdf wurde nicht gefunden.' }
    Write-Host "OCRmyPDF Version: $(& $ocrmypdf.Source --version)"

    if (-not (Get-Command gswin64c -ErrorAction SilentlyContinue) -and
        -not (Test-Path "$env:ProgramFiles\gs")) {
        Write-Host ''
        Write-Host 'Hinweis: Ghostscript ist nicht installiert. Das ist optional.' -ForegroundColor Yellow
        Write-Host 'OCR funktioniert trotzdem; Ghostscript verbessert nur die PDF/A-Umwandlung in Sonderfaellen.'
        Write-Host 'Download bei Bedarf: https://ghostscript.com/releases/gsdnld.html'
    }

    Write-Host ''
    Write-Host 'Fertig! Jetzt "OCR starten.bat" doppelklicken.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
