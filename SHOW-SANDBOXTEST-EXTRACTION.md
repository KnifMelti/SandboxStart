# Complete Extraction Instructions for Show-SandboxTestDialog.ps1

## Problem
The error "Find-MatchingScript is not recognized" occurs because helper functions are missing.

## Solution
Extract the ENTIRE Show-SandboxTestDialog function INCLUDING its nested helper functions.

## Exact Extraction Steps:

### From WAU-Settings-GUI.ps1:

1. **Find the start**: Search for `function Show-SandboxTestDialog {` (around line 900)

2. **Extract EVERYTHING until the matching closing brace** which includes:
   - The complete function definition
   - ALL nested functions inside it:
     - `Get-ScriptMappings`
     - `Find-MatchingScript`
     - `Get-StableWinGetVersions`
   - All default scripts definitions
   - All Windows Forms UI code
   - The return statement at the end

3. **The function ends** at the closing `}` around line 2300

4. **Save as**: `Show-SandboxTestDialog.ps1`

5. **Add at the TOP** of the file (before the function):
```powershell
# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
```

6. **Required modifications**:
   - Change ALL instances of `$WorkingDir` to `$Script:WorkingDir`
   - OR add at the top: `$WorkingDir = $PSScriptRoot`

## Structure to Extract:

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-SandboxTestDialog {
    # [Line ~900] Function starts here
    
    # Default scripts definition
    $defaultScripts = @{ ... }
    
    # WSB directory setup
    $wsbDir = Join-Path $WorkingDir "wsb"
    # ... create default scripts ...
    
    # NESTED FUNCTION 1
    function Get-ScriptMappings {
        # Reads wsb\script-mappings.txt
        # Returns array of pattern→script mappings
    }
    
    # NESTED FUNCTION 2
    function Find-MatchingScript {
        param([string]$Path, [string]$FileName = $null)
        # Matches files against patterns
        # Returns appropriate script name
    }
    
    # NESTED FUNCTION 3
    function Get-StableWinGetVersions {
        # Fetches WinGet versions from GitHub
        # Returns array of version strings
    }
    
    # Windows Forms UI creation
    $form = New-Object System.Windows.Forms.Form
    # ... all controls ...
    # ... all event handlers ...
    
    # Show dialog and return result
    $form.ShowDialog() | Out-Null
    return $script:__dialogReturn
    
} # [Line ~2300] Function ends here
```

## Key Points:

1. **Do NOT extract functions separately** - they are nested INSIDE Show-SandboxTestDialog
2. **Do NOT modify the function structure** - just copy as-is
3. **The entire block is ~1400 lines** - this is correct
4. **Three nested functions are required**:
   - `Get-ScriptMappings` (~60 lines)
   - `Find-MatchingScript` (~40 lines)  
   - `Get-StableWinGetVersions` (~30 lines)

## Variable Reference:

The function uses `$WorkingDir` which needs to be defined. Choose ONE approach:

**Option A** (Recommended): Change all references
```powershell
# Find: $WorkingDir
# Replace with: $Script:WorkingDir
```

**Option B**: Add at top of file
```powershell
$WorkingDir = $PSScriptRoot
```

## Verification:

After extraction, the file should:
- ✅ Be approximately 1400-1500 lines
- ✅ Start with `Add-Type` assembly loading
- ✅ Contain `function Show-SandboxTestDialog {`
- ✅ Contain three nested `function` definitions inside
- ✅ End with `return $script:__dialogReturn` and closing `}`
- ✅ Have NO syntax errors when dot-sourced

## Testing:

```powershell
# Should load without errors
. .\Show-SandboxTestDialog.ps1

# Should show dialog
$result = Show-SandboxTestDialog
```

If you get "Find-MatchingScript not recognized", the nested functions weren't included.
If you get "WorkingDir not found", add the variable definition at the top.
