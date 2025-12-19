# SandboxStart - Slutlig Sammanfattning

## Vad har skapats:

### ✅ Färdiga filer (i /home/claude/SandboxStart/):

1. **SandboxStart.ps1** (157 rader)
   - Huvudstartfil
   - Kontrollerar WSB-tillgänglighet
   - Startar GUI-dialog
   - Kör SandboxTest med konfiguration

2. **Test-WindowsSandbox.ps1** (147 rader)
   - Detekterar om Windows Sandbox är installerat
   - Erbjuder automatisk installation om saknas
   - Hanterar pending reboot-scenarion

3. **README.md**
   - Komplett dokumentation
   - Användningsexempel
   - Script mapping-förklaring
   - Troubleshooting

4. **EXTRACTION_GUIDE.md**
   - Detaljerad guide för extraktion
   - Radnummer och sektioner
   - Alternativa metoder

## Vad behöver kopieras manuellt:

### ❌ SandboxTest.ps1 (~1800 rader)
**Källa:**
```
WAU-Settings-GUI/Sources/WAU Settings GUI/SandboxTest.ps1
```

**Destination:**
```
SandboxStart/SandboxTest.ps1
```

**Åtgärd:**
- Kopiera hela filen OFÖRÄNDRAD
- Denna fil är redan generisk och WAU-oberoende
- Inga modifieringar behövs

### ❌ Show-SandboxTestDialog.ps1 (~1400 rader)
**Källa:**
```
WAU-Settings-GUI/Sources/WAU Settings GUI/WAU-Settings-GUI.ps1
```

**Radområde:** ~900-2300

**Extraction method:**
1. Öppna WAU-Settings-GUI.ps1
2. Sök efter: `function Show-SandboxTestDialog {`
3. Kopiera hela funktionen till matchande avslutande `}`
4. Spara som: `SandboxStart/Show-SandboxTestDialog.ps1`
5. Lägg till i toppen:
   ```powershell
   Add-Type -AssemblyName System.Windows.Forms
   Add-Type -AssemblyName System.Drawing
   ```

**Ändringar som behövs:**
- Byt `$WorkingDir` mot `$Script:WorkingDir` eller `$PSScriptRoot`
- Inga andra ändringar behövs - funktionen är redan generisk

## Projektstruktur efter kopiering:

```
SandboxStart/
├── SandboxStart.ps1              ✅ Klar
├── Test-WindowsSandbox.ps1       ✅ Klar  
├── SandboxTest.ps1               ❌ Behöver kopieras
├── Show-SandboxTestDialog.ps1    ❌ Behöver kopieras
├── README.md                     ✅ Klar
├── EXTRACTION_GUIDE.md           ✅ Klar
└── wsb/                          (Skapas automatiskt vid körning)
    ├── script-mappings.txt
    ├── InstallWSB.ps1
    ├── WinGetManifest.ps1
    ├── Installer.ps1
    └── Explorer.ps1
```

## Användning efter färdigställande:

### Grundläggande:
```powershell
.\SandboxStart.ps1
```

### Portabelt läge (USB-minne):
```powershell
.\SandboxStart.ps1 -Portable
```

## Testning:

Efter att du kopierat de 2 saknade filerna:

1. Kör: `.\SandboxStart.ps1`
2. Om WSB inte är installerat: följ prompten för installation
3. GUI-dialog ska visas
4. Välj mapp och klicka OK
5. Windows Sandbox ska starta med din konfiguration

## Nyckelfunktioner:

### Automatisk WSB-installation
- Detekterar om Windows Sandbox saknas
- Promptar för installation
- Hanterar restart-krav

### GUI-dialog
- Folder/file browser
- Script editor med syntax
- WinGet version-väljare
- Auto-detection av filtyper
- Load/Save custom scripts

### Script Mapping
- Automatisk igenkänning av:
  - InstallWSB.cmd filer
  - WinGet manifests (*.installer.yaml)
  - Installer-filer (Install.*, Setup.exe)
  - Fallback till Explorer

### Anpassningsbara scripts
- 4 fördefinierade scripts
- Skapa egna i wsb/ mappen
- Konfigurera patterns i script-mappings.txt

## Viktiga detaljer:

### Script-variabel
Alla scripts har tillgång till:
```powershell
$SandboxFolderName  # Namnet på den mappade mappen i sandbox Desktop
```

### WinGet-integrering
- Automatisk installation i sandbox
- Välj specifik version eller latest
- Stöd för pre-release versioner
- Cache-rensning om problem

### Körlägen
- **Sync**: Vänta på sandbox att stänga
- **Async**: Starta och fortsätt arbeta
- **Verbose**: Detaljerad output
- **Wait**: Vänta på keypress före avslut

## Felsökning:

### Om WSB inte startar:
1. Kontrollera att Windows Sandbox är aktiverat
2. Restart datorn om nyligen aktiverat
3. Kör som Administrator

### Om script inte körs:
1. Kontrollera PowerShell-syntax
2. Använd -Verbose för debug
3. Testa script lokalt först

### Om WinGet inte installeras:
1. Kontrollera internetanslutning
2. Använd -Clean för att rensa cache
3. Specifiera en känd fungerande version

## Licens och Credits:

- Baserat på Microsoft's SandboxTest
- Integrerat i KnifMelti/WAU-Settings-GUI
- Extraherat till fristående projekt
- Samma licens som parent-projektet

## Nästa steg:

1. Kopiera `SandboxTest.ps1` från WAU Settings GUI
2. Extrahera `Show-SandboxTestDialog` funktionen från WAU-Settings-GUI.ps1
3. Testa med: `.\SandboxStart.ps1`
4. Anpassa default scripts efter behov
5. Skapa egna custom scripts i wsb/ mappen

---

**Status:** 2 av 4 kärnfiler färdiga. 2 filer väntar på manuell kopiering.

**Estimated time to complete:** 10-15 minuter för kopiering och minimal anpassning.
