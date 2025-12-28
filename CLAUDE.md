# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SandboxStart is a Windows Sandbox testing tool for easily testing applications, scripts, and installers in an isolated environment. It provides a GUI for configuring sandbox parameters, automatic WinGet installation, and a script mapping system.

**Key Dependencies:**
- Windows 10/11 Pro/Enterprise/Education with Windows Sandbox feature
- PowerShell 5.1+
- Git submodule: `Source/shared/` ([SandboxTest-Shared](https://github.com/KnifMelti/SandboxTest-Shared))

## Development Environment

### Running from Source

Always work in the `Source/` directory when developing:

```powershell
cd Source
.\SandboxStart.ps1
```

**Important:** Release ZIPs extract scripts to root level (no `Source/` folder), but development always happens in `Source/`.

### Git Submodule Management

The `Source/shared/` directory is a git submodule containing shared code used by both SandboxStart and WAU-Settings-GUI:

```powershell
# Initialize submodule (first time)
git submodule update --init --recursive

# Update submodule to latest
cd Source/shared
git pull origin master
cd ../..
git add Source/shared
git commit -m "Update submodule commit reference"
```

## Architecture

### Core Entry Point Flow

1. **SandboxStart.ps1** (main launcher)
   - Loads required functions from `Test-WindowsSandbox.ps1` and `Update-StartMenuShortcut.ps1`
   - Creates/updates Start Menu shortcut (with automatic "follow-script-location" feature)
   - Checks Windows Sandbox availability (prompts to install if missing)
   - Loads and executes the GUI dialog from `shared/Show-SandboxTestDialog.ps1`

2. **Test-WindowsSandbox.ps1**
   - Detects if Windows Sandbox is installed
   - Offers to enable the feature if disabled (requires admin)
   - Handles pending reboot scenarios after feature enablement

3. **Update-StartMenuShortcut.ps1**
   - Manages Start Menu shortcut creation and updates
   - Detects when script location changes and updates shortcut accordingly
   - Returns `$true` if shortcut was just created (triggers restart from shortcut to show custom icon)

4. **shared/Show-SandboxTestDialog.ps1** (GUI)
   - Displays Windows Forms dialog for configuration
   - Handles script mapping logic (pattern matching from `wsb/script-mappings.txt`)
   - Downloads default scripts from GitHub when needed
   - Calls `SandboxTest` function with configured parameters

5. **shared/SandboxTest.ps1** (core sandbox function)
   - Downloads and caches WinGet CLI and dependencies
   - Generates Windows Sandbox configuration (`.wsb` XML file)
   - Creates bootstrap script executed inside sandbox
   - Launches Windows Sandbox with configured parameters

### Script Mapping System

The script mapping system in `wsb/script-mappings.txt` uses pattern matching to automatically select appropriate scripts:

**Format:** `FilePattern = ScriptToExecute.ps1`

**Default Mappings:**
- `InstallWSB.cmd` → `Std-WAU.ps1` (WAU installer test)
- `*.installer.yaml` → `Std-Manifest.ps1` (WinGet manifest validation)
- `*.*` → `Std-Install.ps1` (Universal fallback - smart installer detection)

**Script Types:**
- **Default scripts** (`Std-*.ps1`): Downloaded from GitHub assets when pattern detected, cannot be directly saved in GUI
- **Custom scripts**: User-created scripts in `wsb/` directory, can be saved and edited

### Default Script Locations

Default scripts exist in two locations:
- `Source/assets/scripts/` - GitHub source (used for releases and downloads)
- `Source/wsb/` - Working directory copies (created/downloaded at runtime)

When a folder is selected in the GUI, the script mapping system:
1. Checks file patterns against `wsb/script-mappings.txt`
2. Downloads default script from GitHub if pattern matches and file is different/missing
3. Loads script content into editor

### Shared Utilities (Common-Helpers.ps1)

**Status:** Planned but not yet implemented.

Located in `Source/shared/Common-Helpers.ps1`, will provide 8 utility functions to reduce code duplication:

- `Ensure-DirectoryExists` - Creates directory if missing
- `Write-AsciiFile` - Writes ASCII-encoded files
- `Join-PathMulti` - Joins multiple path segments
- `Test-ValidFolderName` - Validates folder names (not drive roots)
- `Get-DriveLetterFromPath` - Extracts drive letter from path
- `Get-SandboxFolderName` - Converts paths to sandbox folder names (e.g., `C:\` → `Drive_C`)
- `Invoke-SilentProgress` - Executes blocks with suppressed progress output
- `Read-FileContent` - Reads entire file as single string

### Sandbox Execution Flow

When sandbox launches, the following occurs (inside sandbox):

1. **Pre-Install Initialization** (embedded in bootstrap script)
   - Syncs dark mode settings from host
   - Enables clipboard history
   - Creates desktop shortcuts (CMTrace, Sysinternals Live, NirSoft Utilities, CTT Windows Utility)
   - Configures Explorer settings (show file extensions, hidden files)
   - Sets execution policy to Bypass

2. **WinGet Installation** (if networking enabled)
   - Extracts dependencies from cached `.zip`/`.appx` files
   - Installs WinGet CLI via Add-AppxPackage
   - Falls back to PowerShell module method if package installation fails
   - Applies WinGet settings (enables local manifests, disables malware scan)

3. **Package Installation** (optional, if package list specified)
   - Reads `packages.txt` (WinGet package IDs, one per line)
   - Installs each package using `winget install`
   - Shows installation summary

4. **User Script Execution**
   - Executes `BoundParameterScript.ps1` (contains pre-install + user script)
   - For WAU installations: Waits for installation completion, then runs post-install config

5. **Cleanup**
   - Removes temporary files (`Std-File.ps1`, `packages.txt`)
   - Waits for keypress before closing PowerShell window

### WAU (Winget-AutoUpdate) Special Handling

When `InstallWSB.cmd` is detected (WAU installation):

1. User script is modified to wait for WAU installation completion (polls registry + file system)
2. Post-install initialization runs AFTER WAU completes:
   - Creates shortcut to WAU installation directory
   - Configures Registry Editor favorites
   - Creates AdvancedRun config for testing WAU with Notepad++/InstEd

This two-phase initialization prevents shortcuts from breaking due to unknown installation paths.

### File Encoding

**Critical:** All PowerShell scripts and configuration files MUST use **Windows CRLF line endings** and **ASCII encoding**:

- Scripts written to sandbox use `Out-File -Encoding ASCII`
- This ensures compatibility within Windows Sandbox environment
- GitHub default scripts are stored with CRLF endings

## Key Variables

### In SandboxTest.ps1

- `$script:SandboxDesktopFolder` - Always `C:\Users\WDAGUtilityAccount\Desktop`
- `$script:SandboxWorkingDirectory` - Desktop path inside sandbox where mapped folder appears
- `$script:PrimaryMappedFolder` - Host folder path being mapped into sandbox
- `$SandboxFolderName` - Name of folder on sandbox desktop (auto-generated or user-specified)
- `$script:TestDataFolder` - Host cache folder for WinGet dependencies and bootstrap scripts
- `$script:ConfigurationFile` - Path to generated `.wsb` file

### Placeholder Variables in Scripts

Default scripts use placeholder variables that are replaced at runtime:

- `$SandboxFolderName` - Replaced with actual folder name chosen by user/auto-generated
- `PLACEHOLDER_APPS_LIGHT_THEME` - Replaced with host's AppsUseLightTheme registry value
- `PLACEHOLDER_SYSTEM_LIGHT_THEME` - Replaced with host's SystemUsesLightTheme registry value

Example from `Std-Install.ps1`:
```powershell
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"
```

This becomes (at runtime):
```powershell
$sandboxPath = "$env:USERPROFILE\Desktop\MyTestFolder"
```

## Common Development Tasks

### Modifying a Default/adding a new Script

1. Edit the script in `Source/assets/scripts/ScriptName.ps1`
2. Use `$SandboxFolderName` variable (will be replaced at runtime)
3. Add mapping to `Source/wsb/script-mappings.txt`
4. Upload script to GitHub releases as asset (for automatic download)
5. For adding a new Default Script the code in project must be modified too

### Modifying the GUI Dialog

Edit `Source/shared/Show-SandboxTestDialog.ps1`. Key sections:

- Form controls creation (buttons, textboxes, checkboxes)
- Script mapping logic (`Get-ScriptMappings`, `Select-ScriptForFolder`)
- Default script download logic (`Download-DefaultScript`)
- Form validation and parameter building for `SandboxTest` call

### Debugging Sandbox Execution

1. Use `-Verbose` parameter in GUI to see detailed output
2. Bootstrap script (`SandboxTest.ps1`) is written to `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\`
3. Check `BoundParameterScript.ps1` in same location to see combined pre-install + user script
4. Sandbox logs appear in PowerShell window (maximized) inside sandbox
5. Enable "Wait for keypress before closing" by using Verbose mode

### Testing Script Mapping Changes

1. Modify `Source/wsb/script-mappings.txt`
2. Run `Source/SandboxStart.ps1`
3. Browse to test folder
4. Verify correct script is loaded in editor

### Modifying Shared Code (Submodule)

When editing files in `Source/shared/`:

1. Make changes in the submodule
2. Commit changes in submodule repository first
3. Update parent repository to reference new submodule commit:
   ```powershell
   git add Source/shared
   git commit -m "Update submodule commit reference (description of changes)"
   ```

## Code Patterns

### Creating Windows Sandbox Configuration

The `.wsb` file is generated dynamically by `SandboxTest.ps1`:

```xml
<Configuration>
  <Networking>Enable|Disable</Networking>
  <MemoryInMB>4096</MemoryInMB>
  <vGPU>Default|Enable|Disable</vGPU>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Path\To\Folder</HostFolder>
      <SandboxFolder>C:\Users\WDAGUtilityAccount\Desktop\FolderName</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>PowerShell Start-Process PowerShell -WindowStyle Maximized ...</Command>
  </LogonCommand>
</Configuration>
```

### Error Handling Pattern

Follow the existing pattern:

```powershell
try {
    # Operation
}
catch {
    Write-Error "Descriptive message: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show(
        $errorMsg,
        "Error Title",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    return $false
}
```

### Shortcut Creation Pattern

Use the `Add-Shortcut` function embedded in sandbox pre-install script:

```powershell
Add-Shortcut $TargetPath $ShortcutPath $Arguments $IconPath $Description $WindowStyle
```

## Testing

### Manual Testing Workflow

1. Run from `Source/SandboxStart.ps1`
2. Test with different folder types:
   - Folder containing `InstallWSB.cmd` (WAU test)
   - Folder containing `*.installer.yaml` (manifest test)
   - Folder containing installer files (`Setup.exe`, `Install.msi`, etc.)
   - Root drive (e.g., `D:\`)
   - Empty folder (should open Explorer)
3. Test with different sandbox configurations:
   - Networking disabled
   - Different memory allocations
   - GPU virtualization settings
4. Test script editor features:
   - Load/Save custom scripts
   - Edit mappings
   - Clear editor
5. Test package list installation

### Known Edge Cases

- **Drive root mapping** (e.g., `C:\`): Automatically renamed to `Drive_C` in sandbox
- **Pending sandbox processes**: Tool automatically kills running `WindowsSandbox.exe` before launching
- **File locking**: 3-second delay after killing processes to allow file handles to release
- **WinGet cache corruption**: Use "Clean" option to clear cached dependencies
- **Admin rights**: Required for enabling Windows Sandbox feature, but not for running sandbox itself

## Release Process

Releases are created from `Source/` directory contents. The release structure flattens the hierarchy:

```
Release ZIP:
  SandboxStart.ps1
  startmenu-icon.ico
  Test-WindowsSandbox.ps1
  Update-StartMenuShortcut.ps1
  shared/
    SandboxTest.ps1
    Show-SandboxTestDialog.ps1
    Common-Helpers.ps1
    ...
```

End users run from root level (no `Source/` folder).

## Important Constraints

1. **Never hardcode paths** - Always use `$SandboxFolderName` placeholder in default scripts
2. **Always use ASCII encoding** - Sandbox scripts must be ASCII-encoded with CRLF line endings
3. **Preserve dark mode sync** - When modifying pre-install script, maintain theme detection logic
4. **Handle missing WinGet gracefully** - Support networking disabled mode
5. **Admin rights handling** - Clearly communicate when admin rights are needed (feature enablement only)
6. **Submodule changes require two commits** - First in submodule repo, then parent repo update
7. **English only** - All comments, documentation, and text in code must be in English
