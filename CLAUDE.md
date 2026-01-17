# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Structure

SandboxStart documentation is organized as follows:

- **README.md** - Quick start guide and overview (simplified)
- **GitHub Wiki** - User documentation (4 pages)
  - Getting Started - Installation and first steps
  - User Guide - Features and examples
  - Troubleshooting - Common issues and solutions
  - FAQ - Frequently asked questions
- **CLAUDE.md** - Detailed developer/AI assistant reference (this file)

When helping users, direct them to the appropriate wiki page for user-facing information. Developer/technical details remain in this file.

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
   - Accepts `$SkipWinGetInstallation` parameter to enable network-only mode
   - When enabled, skips all WinGet download/installation but preserves pre-install initialization

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

### Sandbox Execution Flow

When sandbox launches, the following occurs (inside sandbox):

1. **Pre-Install Initialization** (embedded in bootstrap script)
   - Syncs dark mode settings from host
   - Enables clipboard history
   - Creates desktop shortcuts (CMTrace, Sysinternals Live, NirSoft Utilities, CTT Windows Utility)
   - Configures Explorer settings (show file extensions, hidden files)
   - Sets execution policy to Bypass

2. **WinGet Installation** (if networking enabled AND WinGet not skipped)
   - Extracts dependencies from cached `.zip`/`.appx` files
   - Installs WinGet CLI via Add-AppxPackage
   - Falls back to PowerShell module method if package installation fails
   - Applies WinGet settings (enables local manifests, disables malware scan)
   - **Skipped in network-only mode** - preserves pre-install but skips WinGet entirely

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

### Network-Only Mode

A lightweight mode that enables networking without WinGet installation:

**Use Cases:**
- Quick browser testing without WinGet overhead
- Manual file downloads from websites
- Network-based tool testing
- ~30-60 second faster startup

**Implementation:**
- GUI: `$chkSkipWinGet` checkbox in Runtime Options section (enabled only when networking is checked)
- Parameter: `[switch] $SkipWinGetInstallation` in SandboxTest.ps1
- Behavior: Skips all WinGet-related operations (download, install, config, packages)
- Preserves: Pre-install initialization (dark mode, shortcuts, Explorer settings, clipboard history)

**Code Conditions:**
All WinGet operations are guarded by:
```powershell
if (($Networking -eq "Enable") -and -not $SkipWinGetInstallation) {
    # WinGet operations here
}
```

**Three Modes:**

| Mode | Networking | Skip WinGet | Result |
|------|-----------|-------------|--------|
| **Full Offline** | Disabled | Unchecked (disabled) | No network, no WinGet, pre-install only |
| **Network Only** | Enabled | Checked | Network enabled, no WinGet, pre-install + internet |
| **Full Install** | Enabled | Unchecked | Network + WinGet + packages (default) |

### File Encoding and Indentation

**Critical:** All PowerShell scripts and configuration files MUST use **Windows CRLF line endings** and **TAB characters for indentation**:

- **Windows Sandbox `.wsb` files:** Use `Out-File -Encoding UTF8` (adds BOM, required for XML parsing with international characters)
- **PowerShell scripts written to sandbox:** Use `Out-File -Encoding UTF8` (preserves international characters in `$SandboxFolderName` variable)
- **Config files** (desktop.ini, settings.json, etc.): Use `Out-File -Encoding ASCII` (no international text)
- **Script mappings and package lists:** Use `Set-Content -Encoding ASCII` (metadata only)
- GitHub default scripts are stored with UTF-8 encoding and CRLF endings
- **Always use TAB characters** for indentation, never spaces
- This maintains consistency across all PowerShell files in the project

**Why UTF-8 for user scripts:**
When a user selects a folder "Testmäp", the `$SandboxFolderName` variable is embedded in user scripts. If saved as ASCII, Swedish characters become `???` and the script cannot find the mapped folder inside the sandbox. UTF-8 encoding preserves these characters correctly.

**Important Note (Issue #8):**
- Prior to this fix, `.wsb` files used ASCII encoding which converted non-ASCII characters to `???`
- This caused error 0x8007007b when paths contained international characters
- Solution: Changed to UTF8 encoding in SandboxTest.ps1 for `.wsb` files and all runtime-created scripts
- UTF8 adds BOM (Byte Order Mark) which Windows Sandbox and PowerShell handle correctly

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

### Custom Override for Default Scripts (Std-*.ps1)

Users can override **any** default script (Std-Install.ps1, Std-Manifest.ps1, Std-WAU.ps1, Std-File.ps1) by adding a `# CUSTOM` header. The system automatically detects this header and:
- Enables the Save button in GUI
- Protects the file from GitHub sync overwrites
- Allows full customization of default script behavior

**General Use Cases:**
- Custom installer detection logic (Std-Install.ps1)
- Custom manifest validation (Std-Manifest.ps1)
- Custom WAU installation behavior (Std-WAU.ps1)
- Custom file type handling (Std-File.ps1)
- Add logging, error handling, or special processing to any default script

#### Custom Override: General Instructions (All Std-*.ps1 Scripts)

This works for **Std-Install.ps1, Std-Manifest.ps1, Std-WAU.ps1**:

**Quick Method: Edit in GUI and Save**

1. **Select folder to load default script:**
   - Browse to a folder (script loads based on mappings)
   - Default script appears in editor (e.g., Std-Install.ps1)

2. **Add custom override header:**
   - Add `# CUSTOM` as the **first line** in the editor
   - Add descriptive comment on line 2 (e.g., `# My custom installer with logging`)

3. **Modify and save:**
   - Make your changes to the script
   - Click **"Save"** button (now enabled because of custom header)
   - Script is saved to `Source\wsb\Std-[ScriptName].ps1`
   - GitHub sync will skip this file (won't overwrite)

4. **Future usage:**
   - Next time you select a folder, your custom script loads
   - You can continue to edit and save changes
   - Script executes with your customizations

**Alternative: Via Load Button**

1. Click **"Load..."** button
2. Navigate to `Source\wsb\Std-[ScriptName].ps1`
3. Add `# CUSTOM` as first line
4. Modify the script as needed
5. Click **"Save"** or **"Save As..."**

**Alternative: Via External Editor**

1. Open `Source\wsb\Std-[ScriptName].ps1` in any text editor (VS Code, Notepad++, etc.)
2. Add `# CUSTOM` as the first line
3. Modify the script
4. Save changes (use UTF-8 encoding with CRLF line endings)

#### Custom Override: Std-File.ps1 Specific Instructions

**Std-File.ps1 has special behavior** because it uses parameter blocks that must execute correctly:

**Method 1: Via GUI (Recommended for most users)**

1. **Load default script:**
   - Click "Load..." button in the GUI
   - Navigate to `Source\wsb\Std-File.ps1`
   - Script loads in editor

2. **Create custom version:**
   - Add `# CUSTOM` as the **first line** in the editor
   - Add descriptive comment on line 2 (e.g., `# My custom .exe handler`)
   - Modify file type handlers as needed (see switch statement in script)
   - Click "Save As..." and save as `Std-File.ps1` (overwrites default in wsb folder)

3. **Automatic detection and usage:**
   - When you select a file, GUI detects custom header
   - Status message shows "using CUSTOM Std-File.ps1"
   - A wrapper script is shown in editor (not the full custom script content)
   - Custom script will be executed in sandbox with proper parameters
   - GitHub sync will skip this file (won't overwrite)

4. **Editing custom script:**
   - To edit your custom Std-File.ps1, click "Load..." button
   - Navigate to `Source\wsb\Std-File.ps1` and open it
   - Make your changes in the editor
   - Click "Save" to save changes (Save button is enabled for custom scripts)
   - On next file selection, your updated custom script will be used

**Method 2: Via External Editor**

1. Open `Source\wsb\Std-File.ps1` in any text editor (VS Code, Notepad++, etc.)
2. Add `# CUSTOM` as the first line
3. Modify file type handlers as needed
4. Save changes (use UTF-8 encoding with CRLF line endings)

**Example Custom Header:**

```powershell
# CUSTOM
# My custom file handler - logs all .exe executions to Desktop
# Std-File.ps1 - Execute files in Windows Sandbox

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SandboxFolderName,
	[Parameter(Mandatory)]
	[string]$FileName
)

# Custom logging
$logFile = "$env:USERPROFILE\Desktop\FileExecutions.log"
"$(Get-Date) - Executing: $FileName" | Out-File $logFile -Append

# Rest of script...
```

**GitHub Sync Protection:**

The `Sync-GitHubScriptsSelective` function in `Shared-Helpers.ps1` checks for the regex pattern `^\s*#\s*CUSTOM\s+OVERRIDE` and skips syncing if found.

**Supported header formats:**
- `# CUSTOM` (standard)
- `#CUSTOM` (no space after #)
- `  # CUSTOM` (leading whitespace)

**Reverting to Default:**

1. **Delete file method:** Delete `wsb\Std-File.ps1` → GitHub sync re-downloads default on next GUI run
2. **Remove header method:** Remove the `# CUSTOM` line → GitHub sync overwrites on next run

**Important Notes:**

- Custom scripts must use UTF-8 encoding with CRLF line endings (Windows standard)
- Always test custom scripts thoroughly before using in production
- Default script parameters (`$SandboxFolderName`, `$FileName`) must be preserved
- Custom scripts can add additional parameters or logic as needed

**Summary: Behavior Differences Between Scripts**

| Script | Selection Method | GUI Display | Execution | Editing |
|--------|-----------------|-------------|-----------|---------|
| **Std-Install.ps1** | Select folder | Full script in editor | Runs inline | Edit directly & Save |
| **Std-Manifest.ps1** | Select folder with `.installer.yaml` | Full script in editor | Runs inline | Edit directly & Save |
| **Std-WAU.ps1** | Select folder with `InstallWSB.cmd` | Full script in editor | Runs inline | Edit directly & Save |
| **Std-File.ps1** | Select individual file | Wrapper script in editor | Calls .ps1 file | Load → Edit → Save |

**Why Std-File.ps1 is different:**
- Uses `[CmdletBinding()]` and `param()` blocks that require file execution
- Must be called as a script file (not run inline) for parameters to work correctly
- GUI shows wrapper to ensure proper execution
- To edit: Use Load button to view/edit full script content

### Advanced: Using WinGet Configuration Files (.winget)

**For power users:** WinGet Configuration (DSC) files provide declarative package installation with advanced features like dependency management and configuration-as-code.

#### What are .winget Files?

WinGet Configuration files use YAML/JSON syntax to define:
- Packages to install with version constraints
- Complex dependency chains
- WinGet settings and sources
- Conditional installations based on environment

**Example .winget file:**
```yaml
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: powershell
      directives:
        description: Install PowerShell 7
        securityContext: elevated
      settings:
        id: Microsoft.PowerShell
        source: winget
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: vsPackage
      directives:
        description: Install Visual Studio 2022 Community
        securityContext: elevated
      settings:
        id: Microsoft.VisualStudio.2022.Community
        source: winget
  configurationVersion: 0.2.0
```

#### Integration with SandboxStart

SandboxStart doesn't have built-in GUI support for .winget files, but power users can easily integrate them using custom scripts.

**Method 1: Custom Std-Install.ps1 (Recommended)**

Create a custom override that automatically detects and executes .winget files:

1. **Create custom Std-Install.ps1:**
   - Select any folder in GUI to load default Std-Install.ps1
   - Add `# CUSTOM` as first line
   - Add `# WinGet Configuration Handler` as second line
   - Add detection logic (see example below)
   - Click Save

2. **Example custom script:**

```powershell
# CUSTOM
# WinGet Configuration Handler - Detects and runs .winget files

# Standard variables (replaced at runtime)
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"

# Check for .winget configuration files
$wingetFiles = Get-ChildItem -Path $sandboxPath -Filter "*.winget" -File -ErrorAction SilentlyContinue

if ($wingetFiles) {
	Write-Host "`n=== WinGet Configuration Detected ===" -ForegroundColor Cyan

	foreach ($wingetFile in $wingetFiles) {
		Write-Host "`nExecuting configuration: $($wingetFile.Name)" -ForegroundColor Yellow

		try {
			# Run WinGet configuration
			winget configure --file $wingetFile.FullName --accept-configuration-agreements --verbose

			if ($LASTEXITCODE -eq 0) {
				Write-Host "`n[SUCCESS] Configuration applied: $($wingetFile.Name)" -ForegroundColor Green
			} else {
				Write-Host "`n[ERROR] Configuration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
			}
		}
		catch {
			Write-Error "Failed to execute WinGet configuration: $_"
		}
	}

	Write-Host "`n=== WinGet Configuration Complete ===" -ForegroundColor Cyan
} else {
	# Fallback to standard installer detection
	Write-Host "No .winget files found. Searching for installers..." -ForegroundColor Yellow

	# Insert standard installer detection logic here
	# (copy from default Std-Install.ps1)
}

Write-Host "`nScript execution complete." -ForegroundColor Green
```

3. **Usage:**
   - Place `.winget` file in your test folder
   - Select folder in SandboxStart GUI
   - Your custom script automatically detects and runs the configuration
   - Falls back to standard installer detection if no .winget files found

**Method 2: Dedicated Custom Script**

Create a separate custom script specifically for .winget files:

1. **Create new script:**
   - Click "Load..." in GUI
   - Save as `Custom-WinGetConfig.ps1` in `wsb/` folder

2. **Script content:**

```powershell
# Custom-WinGetConfig.ps1
# Executes WinGet Configuration files in sandbox

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SandboxFolderName,

	[Parameter()]
	[string]$ConfigFileName = "*.winget"
)

$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"

Write-Host "=== WinGet Configuration Runner ===" -ForegroundColor Cyan
Write-Host "Searching for configuration files matching: $ConfigFileName" -ForegroundColor Yellow

$wingetFiles = Get-ChildItem -Path $sandboxPath -Filter $ConfigFileName -File -ErrorAction SilentlyContinue

if (-not $wingetFiles) {
	Write-Error "No WinGet configuration files found in $sandboxPath"
	Write-Host "Expected file pattern: $ConfigFileName" -ForegroundColor Yellow
	exit 1
}

foreach ($wingetFile in $wingetFiles) {
	Write-Host "`nApplying configuration: $($wingetFile.Name)" -ForegroundColor Cyan
	Write-Host "File path: $($wingetFile.FullName)" -ForegroundColor Gray

	# Display file content for debugging
	Write-Host "`nConfiguration content:" -ForegroundColor Yellow
	Get-Content $wingetFile.FullName | Write-Host -ForegroundColor Gray

	Write-Host "`nExecuting configuration..." -ForegroundColor Yellow

	try {
		winget configure --file $wingetFile.FullName --accept-configuration-agreements --verbose

		if ($LASTEXITCODE -eq 0) {
			Write-Host "`n[SUCCESS] Configuration applied successfully" -ForegroundColor Green
		} else {
			Write-Host "`n[ERROR] Configuration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
		}
	}
	catch {
		Write-Error "Exception during configuration: $_"
	}
}

Write-Host "`n=== Configuration Complete ===" -ForegroundColor Cyan
```

3. **Usage:**
   - Load the custom script manually in GUI
   - Browse to folder containing .winget file
   - Click Test to execute

**Method 3: Script Mapping (Advanced)**

Add automatic mapping for .winget files:

1. **Edit `wsb/script-mappings.txt`:**
   ```
   *.winget = Custom-WinGetConfig.ps1
   ```

2. **Create `Custom-WinGetConfig.ps1`** (use Method 2 script above)

3. **Usage:**
   - Select folder or file with `.winget` extension
   - Script automatically loads and executes

#### Requirements and Considerations

**Prerequisites:**
- WinGet must be installed in sandbox (enable Networking in GUI)
- Do NOT enable "Skip WinGet installation" checkbox
- .winget files require WinGet CLI version 1.6.0 or later

**Limitations:**
- No GUI editor for .winget files (edit externally with VS Code/Notepad++)
- No GitHub sync for custom .winget files
- Complex JSON/YAML syntax (requires technical knowledge)
- Error messages can be cryptic

**When to Use .winget vs Package Lists:**

| Feature | Package Lists (.txt) | WinGet Config (.winget) |
|---------|---------------------|------------------------|
| **Complexity** | Low (one package per line) | High (YAML/JSON) |
| **GUI Support** | Full (editor + dropdown) | None (external editor) |
| **Dependencies** | Manual (list packages in order) | Automatic (declarative) |
| **Version Locking** | No | Yes |
| **Configuration** | No | Yes (settings, sources) |
| **Learning Curve** | Minimal | Steep |
| **Best For** | Quick testing, simple installations | Dev environments, reproducible setups |

**Recommendation:**
- Use **package lists** for simple, quick testing scenarios
- Use **.winget files** when you need reproducible development environments or complex dependency chains
- Combine both: AutoInstall.txt for common tools + .winget for project-specific setup

#### Troubleshooting

**"winget configure: command not found":**
- Ensure networking is enabled in GUI
- Verify "Skip WinGet installation" is NOT checked
- WinGet configure requires WinGet CLI 1.6.0+

**"Configuration failed with exit code 1":**
- Check .winget file syntax (validate YAML/JSON)
- Enable `--verbose` flag for detailed error messages
- Verify package IDs exist in WinGet repository

**"Access denied" errors:**
- Some configurations require elevated privileges
- Add `securityContext: elevated` to resource directives
- Note: Sandbox runs as admin by default

#### Additional Resources

- [WinGet Configuration Documentation](https://learn.microsoft.com/en-us/windows/package-manager/configuration/)
- [DSC Schema Reference](https://aka.ms/configuration-dsc-schema/0.2)
- [Example Configurations](https://github.com/microsoft/winget-cli/tree/master/doc/examples/configurations)

### Custom Override for Package Lists (Std-*.txt)

Package lists follow the same CUSTOM pattern as scripts.

**Quick Method: Add Header to Prevent Sync**

1. Open any Std-*.txt package list in a text editor
2. Add `# CUSTOM` as the first line
3. Save the file
4. GitHub sync will now skip this file

**Example:**

```
# CUSTOM
# My customized Python packages
Python.Python.3.14
numpy
pandas
```

**When to use:**
- You've customized a default Std-*.txt list
- You want to prevent GitHub from overwriting your changes
- You want to preserve your package selections

**Reverting to default:**
- Remove the `# CUSTOM` line
- Next GUI startup will sync from GitHub (if changes exist)

**Supported formats:**
- `# CUSTOM` (standard)
- `#CUSTOM` (no space after #)
- `  # CUSTOM` (leading whitespace)

### Package List Configuration System

**Configuration File:** `Source/wsb/config.ini`

A sectioned INI file that manages both package list states and file extension mappings.

**Structure:**
```ini
# SandboxTest Configuration File

[Lists]
# Package list states: 1 = enabled, 0 = disabled/deleted
Python=1
AHK=1
AutoInstall=1
Tools=0
_MigrationCompleted=1

[Extensions]
# Maps file extensions to preferred package lists
# Format: extension=PackageListName
# Fallback: If preferred list doesn't exist, tries variations (Std-AHK -> AHK)
py=Std-Python
ahk=Std-AHK
au3=Std-AU3
```

**Behavior:**
- Auto-created on first GUI startup
- **[Lists] section:** Tracks enabled/disabled state (1 = enabled, 0 = disabled/deleted)
- **[Extensions] section:** Maps file extensions to package lists for auto-selection
- Lists with state=0 are hidden from dropdown
- Preserved during GitHub sync
- Users can add custom extension mappings without code changes

### AutoInstall Package List

**Special List:** `AutoInstall.txt`

A local-only package list that installs automatically before any selected list.

**Characteristics:**
- Created automatically if missing
- Always appears first in dropdown (with ⚙ icon)
- Can be manually selected (installs only AutoInstall packages)
- Can be edited via Edit button
- Cannot be deleted via Delete key
- Never synced from GitHub

**Installation Order:**
1. AutoInstall packages (if exists and not empty)
2. Selected package list (if any)

**Use Cases:**
- Essential tools you want in every sandbox
- Common dependencies needed by multiple test scenarios
- Personal preference applications

**Duplicate Handling:**

If same package appears in both AutoInstall and selected list:
- Installed during AutoInstall phase
- WinGet skips reinstallation in second phase (already installed)

### GitHub Sync for Package Lists

**Naming Convention:** `Std-*.txt` (e.g., Std-Python.txt, Std-AHK.txt)

**Sync Behavior:**
- Downloads if missing locally (unless marked state=0 in .ini)
- Updates if content changed on GitHub
- **Skips if `# CUSTOM` header present**
- **Skips if user deleted the list** (state=0 in .ini)
- Same behavior as Std-*.ps1 scripts

**Skip Conditions:**

The sync will NOT download/update a Std-*.txt file if ANY of these conditions are true:
1. File exists locally with `# CUSTOM` header (respects user customization)
2. File is missing locally AND .ini has `Std-ListName=0` (respects user deletion)

**Remote Cleanup:**
- Detects when Std-*.txt files are removed from GitHub
- Automatically deletes obsolete local versions
- Updates .ini file (sets state to 0)
- Protected by CUSTOM (never deletes customized files)

**Migration System:**

When first upgrading to this version, the system tracks original default list names (Python.txt, AHK.txt, etc.) in the .ini file. If GitHub later introduces Std-* replacements (e.g., Std-Python.txt), the original files are automatically removed and replaced with the GitHub versions.

**Protection:**
- Only tracked original defaults can be deleted during migration
- Lists created after migration are never auto-deleted
- CUSTOM header always prevents deletion

### Deleting Package Lists

**Method:** Press Delete key when a list is selected in the dropdown

**Behavior:**
1. Shows confirmation dialog (themed to match GUI)
2. Deletes the .txt file from wsb/ folder
3. Updates .ini file (sets state to 0)
4. List disappears from dropdown

**Protection:**
- Cannot delete AutoInstall (special list)
- Cannot delete empty selection or "[Create new list...]"

**Important: Std-*.txt Lists (GitHub-synced)**

When deleting a Std-*.txt list (e.g., Std-Python.txt):
- The file is deleted locally
- .ini file is updated with `Std-ListName=0`
- **The list will NOT be re-downloaded** on next GUI startup (user's choice is respected)
- To restore a deleted Std-*.txt list:
  - Remove the `Std-ListName=0` line from .ini file, OR
  - Change `Std-ListName=0` to `Std-ListName=1`
  - Next GUI startup will re-download from GitHub

**User-Created Lists:**
- Deleted lists remain deleted (not on GitHub, so never re-downloaded)
- Can be restored by creating a new list with the same name

### Modifying the GUI Dialog

Edit `Source/shared/Show-SandboxTestDialog.ps1`. Key sections:

- Form controls creation (buttons, textboxes, checkboxes)
- Script mapping logic (`Get-ScriptMappings`, `Select-ScriptForFolder`)
- Default script download logic (`Download-DefaultScript`)
- Form validation and parameter building for `SandboxTest` call

#### Important Considerations for GUI Form Modifications

The GUI form includes automatic high-DPI scaling support (see PR #6). When modifying the form layout, keep these constraints in mind:

**Form Size and Layout Variables:**
- Form size: `465×740` pixels (width × height)
- Control width: `$controlWidth = 409` pixels
- Left margin: `$leftMargin = 20` pixels
- Right margin: ~20 pixels (calculated to keep controls centered)

**High-DPI Scrollbar System:**

The form includes automatic vertical scrollbar support that activates when the form exceeds the screen's working area (at >125% DPI scaling). Key implementation details:

1. **Form.Load Event Handler** (lines ~3324-3374):
   - Captures final Y position: `$finalY = $y`
   - Detects screen WorkingArea (excludes taskbar)
   - Automatically resizes form if it exceeds available screen height
   - Enables AutoScroll with calculated `AutoScrollMinSize`
   - Prevents horizontal scrollbar by subtracting scrollbar width (17px)

2. **Form.Shown Event Handler** (lines ~3376-3385):
   - Force-hides horizontal scrollbar after rendering
   - Calls `PerformLayout()` to refresh layout

**When Adding Controls Vertically:**

If you add new controls that increase the `$y` position (vertical stacking):

```powershell
# Example: Adding a new control
$lblNewControl = New-Object System.Windows.Forms.Label
$lblNewControl.Location = New-Object System.Drawing.Point($leftMargin, $y)
$lblNewControl.Size = New-Object System.Drawing.Size($controlWidth, $labelHeight)
$lblNewControl.Text = "New Control:"
$form.Controls.Add($lblNewControl)
$y += $labelHeight + 5

$txtNewControl = New-Object System.Windows.Forms.TextBox
$txtNewControl.Location = New-Object System.Drawing.Point($leftMargin, $y)
$txtNewControl.Size = New-Object System.Drawing.Size($controlWidth, $controlHeight)
$form.Controls.Add($txtNewControl)
$y += $controlHeight + $spacing + 10  # This increases $y
```

**Considerations:**
- The `$finalY` variable automatically captures the final Y position before buttons
- Content height is calculated as: `$contentHeight = $finalY + 50` (button Y + height + margin)
- If you add many controls, consider increasing `Form.Size` height from 740 to a larger value
- Alternatively, accept that scrollbar will appear at lower DPI levels

**When Modifying Control Width:**

If you change `$controlWidth`:

- Formula to maintain centered layout: `ClientSize.Width ≈ $leftMargin + $controlWidth + scrollBarWidth (17) + margin (5)`
- Current: `449px ≈ 20 + 409 + 17 + 5 = 451px` (fits with 2px tolerance)
- If you increase `$controlWidth` beyond 412px, horizontal scrollbar may appear
- If you decrease `$controlWidth`, increase form width or accept wider right margin

**When Modifying Form Width:**

If you change `Form.Size` width from 465:

- Adjust `$controlWidth` to maintain equal left/right margins
- Formula: `$controlWidth = ClientSize.Width - $leftMargin - rightMargin - scrollBarWidth - tolerance`
- Example: For 20px margins: `$controlWidth = ClientWidth - 20 - 20 - 17 - 5`

**Testing Checklist After GUI Modifications:**

Always test at multiple DPI scaling levels:

```powershell
# Test at these DPI levels:
# - 100% (1920×1080): No scrollbar expected
# - 125%: No scrollbar expected
# - 150%: Vertical scrollbar should appear
# - 175%: Vertical scrollbar should appear

# Verify:
□ No horizontal scrollbar at any DPI level
□ All controls visible and accessible via scrolling
□ Controls remain centered (equal left/right margins)
□ Form doesn't exceed screen height at any DPI level
```

**Quick Reference: Current Layout Dimensions**

```
Form Size:           465×740 pixels
ClientSize:          ~449×701 pixels (at 100% DPI)
Control Width:       409 pixels
Left Margin:         20 pixels
Right Margin:        ~20 pixels
Scrollbar Width:     17 pixels (when visible)
Content Height:      ~700 pixels (calculated from $finalY + 50)
```

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
    Shared-Helpers.ps1
    Show-SandboxTestDialog.ps1
    ...
```

End users run from root level (no `Source/` folder).

## GitHub API Integration and Caching

### Overview

SandboxStart uses a smart GitHub API integration system with caching and fallback mechanisms to minimize rate limiting and improve performance.

**Module:** `Source/shared/Shared-Helpers.ps1`

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
. "Source\shared\Shared-Helpers.ps1"

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
. "Source\shared\Shared-Helpers.ps1"

# Clear GitHub cache
Clear-GitHubCache
```

#### Automatic Cache Clearing

Cache is automatically cleared when user selects "Clean (cached dependencies)" option in GUI.

### API Helper Functions

The `Shared-Helpers.ps1` module provides these functions:

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
-
1. **Never hardcode paths** - Always use `$SandboxFolderName` placeholder in default scripts
2. **Always use ASCII encoding** - Sandbox scripts must be ASCII-encoded with CRLF line endings
3. **Preserve dark mode sync** - When modifying pre-install script, maintain theme detection logic
4. **Handle missing WinGet gracefully** - Support networking disabled mode
5. **Admin rights handling** - Clearly communicate when admin rights are needed (feature enablement only)
6. **Submodule changes require two commits** - First in submodule repo, then parent repo update
7. **English only** - All comments, documentation, and text in code must be in English

## Best Practices for File Editing

### Problem with Edit Tool

The Edit tool requires EXACT character-by-character matching, including:
- Tabs vs spaces (files use tabs for indentation)
- Line endings (CRLF)
- Every single whitespace character

This makes it error-prone and time-consuming when:
- Indentation needs to be changed
- Multiple attempts are needed to match exact whitespace
- Large blocks of code need refactoring

### Recommended Approaches

**For simple, single-line changes:**
1. Give the user specific line numbers and describe the change
2. Let the user make the edit manually (takes 5 seconds in an editor)
3. Example: "On line 2576, remove the `$selectedDir` variable assignment"

**For complex, multi-line changes:**
1. Write a PowerShell script to make the changes programmatically
2. Use `sed`, `awk`, or PowerShell string manipulation
3. Example: Create `fix-script.ps1` that uses `Get-Content`/`Set-Content` with `-replace`
4. This approach is faster, more reliable, and reviewable

**Avoid:**
- Repeatedly trying the Edit tool when it fails to match whitespace
- Trying to guess the exact tab/space combination
- Making multiple attempts with slight variations

**When to use Edit tool:**
- Small, unique string replacements where whitespace doesn't matter
- Changes in files with consistent, simple formatting
- When the old_string is truly unique and easy to match
