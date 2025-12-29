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

**Converting files to CRLF (if created with LF):**

If a file was created with Unix line endings (LF), convert it to Windows CRLF using PowerShell:

```powershell
cd "e:\WinGet\SandboxStart\Source\wsb"
Get-Content FileName.txt | Set-Content -Encoding ASCII FileName_temp.txt
Move-Item -Force FileName_temp.txt FileName.txt
```

Or using bash (if unix2dos available):
```bash
cd "e:\WinGet\SandboxStart\Source\wsb" && unix2dos FileName.txt
```

Verify correct line endings:
```bash
file FileName.txt
# Should output: ASCII text, with CRLF line terminators
```

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

## GitHub API Integration and Caching

### Overview

SandboxStart uses a smart GitHub API integration system with caching and fallback mechanisms to minimize rate limiting and improve performance.

**Module:** `Source/shared/GitHub-ApiHelper.ps1`

### GitHub API Usage

The project makes GitHub API calls for:

1. **WinGet CLI releases** (`microsoft/winget-cli`) - Fetches available WinGet versions
2. **Default scripts listing** (`KnifMelti/SandboxStart`) - Auto-downloads default scripts
3. **Update checking** (`KnifMelti/SandboxStart/releases/latest`) - Checks for new releases

### Rate Limiting

**Without authentication:** 60 requests per hour per IP address
**With Personal Access Token (PAT):** 5,000 requests per hour

### Caching System

**Cache Location:** `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\GitHubCache\`

**Cache Structure:**
- `releases_microsoft_winget-cli.json` - Cached WinGet releases
- `releases_KnifMelti_SandboxStart.json` - SandboxStart releases
- `contents_KnifMelti_SandboxStart_scripts.json` - Default scripts list
- `cache_metadata.json` - Cache timestamps and expiry information

**Cache Behavior:**
- TTL: 60 minutes (configurable)
- Automatic cache validation and expiry handling
- Falls back to expired cache when API is unavailable
- Cache is cleared via "Clean (cached dependencies)" option in GUI

### Fallback Chain

When fetching GitHub data, the system follows this fallback chain:

1. **Try local cache** (if < 60 minutes old)
2. **Try API with PAT** (if `$env:GITHUB_PAT` is set)
3. **Try API without authentication**
4. **Use expired cache** (if available)
5. **Try Atom feed** (for releases only)
6. **Return error** (with clear user message)

### Performance Benefits

- First run: 3-4 API calls (cached for 60 minutes)
- Subsequent runs within cache window: 0 API calls
- **95%+ reduction** in API usage for typical workflows

### Developer Setup: GitHub Personal Access Token (Optional)

**For repository owners and developers only.** End users do not need PAT.

#### Why Use PAT?

- Increases rate limit from 60 to 5,000 requests per hour
- Useful during development/testing with frequent runs
- No downside if not configured (system falls back gracefully)

#### Setup Instructions

1. **Create PAT on GitHub:**
   - Go to: Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token"
   - Name: "SandboxStart Development"
   - Scopes: Select "public_repo" (read access to public repositories)
   - Expiration: Choose appropriate duration
   - Click "Generate token" and **copy the token immediately**

2. **Set Environment Variable:**

```powershell
# In PowerShell session (temporary):
$env:GITHUB_PAT = "ghp_xxxxxxxxxxxx"

# Or in PowerShell profile (permanent):
# Edit: $PROFILE
# Add line: $env:GITHUB_PAT = "ghp_xxxxxxxxxxxx"
```

3. **Verify PAT is Working:**

```powershell
# Run SandboxStart with Verbose mode
.\SandboxStart.ps1 -Verbose

# Look for message: "Using authenticated API request (PAT)"
```

#### Security Warning

**NEVER commit your PAT to Git!**

- PAT tokens provide access to your GitHub account
- If accidentally committed, token becomes public and can be misused
- Always use environment variables (which are not tracked by Git)
- If token is exposed, immediately revoke it on GitHub and create a new one

#### Checking Rate Limit Status

To see your current rate limit:

```powershell
# Load the module
. "Source\shared\GitHub-ApiHelper.ps1"

# Check rate limit
Test-GitHubApiLimit

# Output:
# Remaining : 4998
# Limit     : 5000
# ResetTime : 12/29/2025 11:30:00 AM
```

### Cache Management

#### Manual Cache Clearing

```powershell
# Load the module
. "Source\shared\GitHub-ApiHelper.ps1"

# Clear GitHub cache
Clear-GitHubCache
```

#### Automatic Cache Clearing

Cache is automatically cleared when user selects "Clean (cached dependencies)" option in GUI.

### API Helper Functions

The `GitHub-ApiHelper.ps1` module provides these functions:

- `Get-GitHubReleases` - Fetch releases with caching
- `Get-GitHubFolderContents` - List folder contents with caching
- `Get-GitHubLatestRelease` - Get latest release info
- `Get-GitHubPersonalAccessToken` - Retrieve PAT from environment
- `Test-GitHubApiLimit` - Check rate limit status
- `Clear-GitHubCache` - Clear all cached data
- `Invoke-GitHubApi` - Low-level API wrapper (internal use)
- `ConvertFrom-AtomFeed` - Parse Atom feeds as fallback (internal use)

### Troubleshooting

**"GitHub API rate limit exceeded" warning:**
- You've hit the 60 requests/hour limit
- Wait for rate limit reset (shown in error message)
- Or configure PAT for 5,000 requests/hour

**"Using expired cache data as fallback":**
- API is unavailable or rate limited
- System is using older cached data
- Data may be outdated but functional

**Cache not working:**
- Check cache directory exists: `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\GitHubCache\`
- Clear cache using "Clean" option or `Clear-GitHubCache` function
- Check `cache_metadata.json` for corruption

## Important Constraints

1. **Never hardcode paths** - Always use `$SandboxFolderName` placeholder in default scripts
2. **Always use ASCII encoding** - Sandbox scripts must be ASCII-encoded with CRLF line endings
3. **Preserve dark mode sync** - When modifying pre-install script, maintain theme detection logic
4. **Handle missing WinGet gracefully** - Support networking disabled mode
5. **Admin rights handling** - Clearly communicate when admin rights are needed (feature enablement only)
6. **Submodule changes require two commits** - First in submodule repo, then parent repo update
7. **English only** - All comments, documentation, and text in code must be in English
