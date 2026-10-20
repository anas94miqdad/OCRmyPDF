<!-- SPDX-FileCopyrightText: 2026 Anas Miqdad -->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# OCRmyPDF unter Windows – Ordner per Doppelklick umwandeln

Diese Skripte machen PDFs und Bilder (JPG, PNG, TIFF) durchsuchbar. Alles läuft
lokal auf dem eigenen Rechner: keine Cloud, kein Konto, keine Kosten.

## Einmalig: Installation

1. Diesen Ordner an einen festen Ort kopieren, z. B. `Dokumente\OCR`.
2. **`Installieren.bat`** doppelklicken.
   - Installiert Tesseract (Texterkennung), uv (Python-Paketverwaltung) und
     OCRmyPDF sowie das deutsche Sprachpaket.
   - Windows fragt ggf. nach Administratorrechten.
   - Benötigt einmalig Internet, danach nicht mehr.
3. Ghostscript ist optional. Ohne Ghostscript entsteht in seltenen Fällen ein
   normales PDF statt PDF/A. Download: <https://ghostscript.com/releases/gsdnld.html>

## Benutzung

**Variante A – Eingangsordner**

1. **`OCR starten.bat`** doppelklicken. Beim ersten Mal wird der Ordner
   `Eingang` angelegt und geöffnet.
2. PDFs/Bilder in `Eingang` legen und `OCR starten.bat` erneut doppelklicken.
3. Die Ergebnisse landen in `Ausgabe` (öffnet sich automatisch).

Bereits umgewandelte Dateien werden beim nächsten Lauf übersprungen.

**Variante B – Drag & Drop**

Dateien oder einen Ordner mit der Maus auf `OCR starten.bat` ziehen.

- Einzelne Datei → `<Name>_OCR.pdf` daneben
- Ordner → Unterordner `OCR` in diesem Ordner

## Handyfotos und unscharfe Scans

Für Handyfotos oder Scans mit niedriger Auflösung **`OCR starten (Handyfotos).bat`**
verwenden (Doppelklick oder Drag & Drop). Das Bild wird für die Texterkennung
hochgerechnet. Die Datei wird dadurch größer. Für mehrspaltige Layouts
(Zeitungen, Poster) besser die normale Variante nehmen.

## Einstellungen

Oben in `ocr-ordner.ps1` (mit dem Editor öffnen):

- `$Sprachen = 'deu+eng'` – Sprachen der Dokumente. Weitere Sprachpakete
  (z. B. `fra`, `ara`) in `installieren.ps1` bei `$Sprachpakete` ergänzen und
  `Installieren.bat` erneut starten.
- `$BildDpi = 300` – angenommene Auflösung für Bilder ohne DPI-Angabe.

## Probleme

| Meldung | Lösung |
|---|---|
| `OCRmyPDF wurde nicht gefunden` | `Installieren.bat` ausführen |
| `winget wurde nicht gefunden` | „App-Installer“ aus dem Microsoft Store installieren oder IT fragen |
| Skript startet nicht / wird blockiert | Auf verwalteten Rechnern kann die IT Skripte sperren – dann IT fragen |
| `Fehlercode 2` | Datei ist beschädigt oder kein echtes PDF/Bild |
| `Fehlercode 8` | PDF ist passwortgeschützt – erst entsperren |

Aktualisieren: `Installieren.bat` erneut ausführen.
