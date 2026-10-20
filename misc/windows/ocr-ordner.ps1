# SPDX-FileCopyrightText: 2026 Anas Miqdad
# SPDX-License-Identifier: MPL-2.0

<#
.SYNOPSIS
    Wandelt PDFs und Bilder mit OCRmyPDF in durchsuchbare PDFs um.

.DESCRIPTION
    Ohne Angabe von Pfaden werden alle Dateien aus dem Ordner "Eingang" neben
    diesem Skript verarbeitet und nach "Ausgabe" geschrieben.

    Werden Dateien oder Ordner uebergeben (z. B. per Drag & Drop auf die
    .bat-Datei), gilt:
      - Datei  -> "<Name>_OCR.pdf" im selben Ordner
      - Ordner -> Unterordner "OCR" in diesem Ordner

    Bereits umgewandelte Dateien werden uebersprungen, solange die Ausgabe
    neuer ist als die Eingabe. Alles laeuft lokal, nichts wird hochgeladen.

.PARAMETER Foto
    Einstellungen fuer Handyfotos und Scans mit niedriger Aufloesung:
    Bild wird fuer die Texterkennung hochgerechnet, Seite als ein Textblock
    gelesen. Fuer mehrspaltige Layouts ungeeignet.
#>

param(
    [switch]$Foto,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Pfade
)

# ---- Einstellungen ----------------------------------------------------------

# Sprachen fuer die Texterkennung, z. B. 'deu', 'eng' oder 'deu+eng'
$Sprachen = 'deu+eng'

# Aufloesung, die fuer Bilder ohne DPI-Angabe angenommen wird
$BildDpi = 300

# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PdfEndungen = @('.pdf')
$BildEndungen = @('.jpg', '.jpeg', '.png', '.tif', '.tiff')

function Find-OcrMyPdf {
    $cmd = Get-Command ocrmypdf -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $kandidat = Join-Path $env:USERPROFILE '.local\bin\ocrmypdf.exe'
    if (Test-Path $kandidat) { return $kandidat }
    return $null
}

function Get-Eingabedateien([string]$Ordner) {
    Get-ChildItem -LiteralPath $Ordner -File |
        Where-Object { ($PdfEndungen + $BildEndungen) -contains $_.Extension.ToLower() } |
        Sort-Object Name
}

function Test-Aktuell([System.IO.FileInfo]$Eingabe, [string]$Ausgabe) {
    if (-not (Test-Path -LiteralPath $Ausgabe)) { return $false }
    return (Get-Item -LiteralPath $Ausgabe).LastWriteTime -gt $Eingabe.LastWriteTime
}

$ocrmypdf = Find-OcrMyPdf
if (-not $ocrmypdf) {
    Write-Host 'OCRmyPDF wurde nicht gefunden. Bitte zuerst "Installieren.bat" ausfuehren.' -ForegroundColor Red
    exit 3
}

# Auftraege sammeln: Liste von @{ Eingabe = FileInfo; Ausgabe = Pfad }
$auftraege = New-Object System.Collections.Generic.List[object]

if (-not $Pfade -or $Pfade.Count -eq 0) {
    $eingang = Join-Path $PSScriptRoot 'Eingang'
    $ausgang = Join-Path $PSScriptRoot 'Ausgabe'
    foreach ($ordner in @($eingang, $ausgang)) {
        if (-not (Test-Path -LiteralPath $ordner)) {
            New-Item -ItemType Directory -Path $ordner | Out-Null
        }
    }
    foreach ($datei in Get-Eingabedateien $eingang) {
        $ziel = Join-Path $ausgang ($datei.BaseName + '.pdf')
        $auftraege.Add(@{ Eingabe = $datei; Ausgabe = $ziel })
    }
    if ($auftraege.Count -eq 0) {
        Write-Host "Der Ordner `"$eingang`" ist leer."
        Write-Host 'Bitte PDFs oder Bilder hineinlegen und das Skript erneut starten.'
        Start-Process explorer.exe -ArgumentList "`"$eingang`""
        exit 0
    }
} else {
    foreach ($pfad in $Pfade) {
        if (Test-Path -LiteralPath $pfad -PathType Container) {
            $ausgang = Join-Path $pfad 'OCR'
            foreach ($datei in Get-Eingabedateien $pfad) {
                $ziel = Join-Path $ausgang ($datei.BaseName + '.pdf')
                $auftraege.Add(@{ Eingabe = $datei; Ausgabe = $ziel })
            }
        } elseif (Test-Path -LiteralPath $pfad -PathType Leaf) {
            $datei = Get-Item -LiteralPath $pfad
            if (($PdfEndungen + $BildEndungen) -notcontains $datei.Extension.ToLower()) {
                Write-Host "Uebersprungen (kein PDF/Bild): $pfad" -ForegroundColor Yellow
                continue
            }
            $ziel = Join-Path $datei.DirectoryName ($datei.BaseName + '_OCR.pdf')
            $auftraege.Add(@{ Eingabe = $datei; Ausgabe = $ziel })
        } else {
            Write-Host "Nicht gefunden: $pfad" -ForegroundColor Yellow
        }
    }
}

$optionen = @(
    '-l', $Sprachen,
    '--rotate-pages',
    '--deskew',
    # Seiten, die schon Text enthalten, unveraendert uebernehmen
    '--mode', 'skip',
    # PDF/A, wenn moeglich; sonst normales PDF (Ghostscript ist optional)
    '--output-type', 'auto'
)
if ($Foto) {
    $optionen += @('--oversample', '450', '--tesseract-pagesegmode', '6')
}

$ok = 0
$uebersprungen = 0
$fehler = New-Object System.Collections.Generic.List[string]
$nr = 0

foreach ($auftrag in $auftraege) {
    $nr++
    $eingabe = $auftrag.Eingabe
    $ausgabe = $auftrag.Ausgabe

    if (Test-Aktuell $eingabe $ausgabe) {
        Write-Host "[$nr/$($auftraege.Count)] Bereits erledigt: $($eingabe.Name)" -ForegroundColor DarkGray
        $uebersprungen++
        continue
    }

    $zielordner = Split-Path -Parent $ausgabe
    if (-not (Test-Path -LiteralPath $zielordner)) {
        New-Item -ItemType Directory -Path $zielordner | Out-Null
    }

    Write-Host ''
    Write-Host "[$nr/$($auftraege.Count)] $($eingabe.Name)" -ForegroundColor Cyan

    & $ocrmypdf @optionen $eingabe.FullName $ausgabe
    $code = $LASTEXITCODE

    # Bilder ohne DPI-Angabe: mit angenommener Aufloesung erneut versuchen
    if ($code -eq 2 -and $BildEndungen -contains $eingabe.Extension.ToLower()) {
        Write-Host "Bild ohne DPI-Angabe, versuche es mit $BildDpi dpi ..." -ForegroundColor Yellow
        & $ocrmypdf @optionen '--image-dpi' $BildDpi $eingabe.FullName $ausgabe
        $code = $LASTEXITCODE
    }

    if ($code -eq 0) {
        $ok++
    } else {
        $fehler.Add("$($eingabe.Name) (Fehlercode $code)")
    }
}

Write-Host ''
Write-Host '---------------------------------------------'
Write-Host "Umgewandelt:       $ok"
Write-Host "Bereits erledigt:  $uebersprungen"
Write-Host "Fehlgeschlagen:    $($fehler.Count)"
foreach ($f in $fehler) { Write-Host "  - $f" -ForegroundColor Red }

if (-not $Pfade -or $Pfade.Count -eq 0) {
    Start-Process explorer.exe -ArgumentList "`"$(Join-Path $PSScriptRoot 'Ausgabe')`""
}

if ($fehler.Count -gt 0) { exit 1 }
