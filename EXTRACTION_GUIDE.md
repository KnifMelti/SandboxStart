# Complete Extraction Guide for SandboxStart Project

## Overview
This guide contains the exact line ranges and sections to extract from WAU-Settings-GUI.ps1

## Files to Extract:

### 1. Show-SandboxTestDialog.ps1

Extract the following sections from `WAU-Settings-GUI.ps1`:

#### Section A: Function Definition & Default Scripts (Lines ~900-1050)
```
function Show-SandboxTestDialog {
    ...
    $defaultScripts = @{
        "InstallWSB" = @'...'@
        "WinGetManifest" = @'...'@
        "Installer" = @'...'@
        "Explorer" = @'...'@
    }
```

#### Section B: WSB Directory & Script Creation (Lines ~1050-1150)
```
    # Ensure wsb directory exists and create default scripts if needed
    $wsbDir = Join-Path $WorkingDir "wsb"
    ...
    # Create script-mappings.txt if it doesn't exist
    $mappingFile = Join-Path $wsbDir "script-mappings.txt"
    ...
```

#### Section C: Helper Functions (Lines ~1150-1400)
```
    function Get-ScriptMappings { ... }
    function Find-MatchingScript { ... }
```

#### Section D: Form Creation (Lines ~1400-2200)
- Form initialization
- All controls (TextBoxes, Buttons, CheckBoxes, ComboBox)
- Event handlers for:
  - Browse folder button
  - Browse file button  
  - Load script button
  - Save script button
  - OK/Cancel buttons
- Auto-detection logic

#### Section E: Return Value (Lines ~2200-2250)
```
    return $script:__dialogReturn
}
```

### Required Modifications:

1. Change `$WorkingDir` to `$Script:WorkingDir` or `$PSScriptRoot`
2. Remove any WAU-specific code (there shouldn't be any in this function)
3. Keep all Windows Forms code intact

---

## Alternative Approach (Simpler):

Since the Show-SandboxTestDialog function in WAU-Settings-GUI.ps1 is **already generic and WAU-independent**, you can:

1. Search for the line: `function Show-SandboxTestDialog {`
2. Extract from that line until the matching closing brace `}`  
3. This entire function (~1300-1500 lines) is standalone
4. Save as `Show-SandboxTestDialog.ps1`
5. Add these lines at the top:
   ```powershell
   Add-Type -AssemblyName System.Windows.Forms
   Add-Type -AssemblyName System.Drawing
   ```

---

## Files Status:

✅ **SandboxStart.ps1** - Main launcher (Created)
✅ **Test-WindowsSandbox.ps1** - WSB detection (Created)
❌ **SandboxTest.ps1** - Core function (Copy from: `Sources/WAU Settings GUI/SandboxTest.ps1`)
❌ **Show-SandboxTestDialog.ps1** - GUI (Extract from: `WAU-Settings-GUI.ps1` function)

---

## Line Numbers Reference (Approximate):

From `WAU-Settings-GUI.ps1`:
- Line ~900: `function Show-SandboxTestDialog {` starts
- Line ~2300: Function ends with closing `}`
- This entire block is ~1400 lines
- It's completely self-contained and generic

