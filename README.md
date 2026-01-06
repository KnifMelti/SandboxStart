[![Windows Sandbox](https://img.shields.io/badge/Windows%20Sandbox-Required-orange.svg)](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/SandboxStart/total)
<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/icon.png" alt="Icon" width="128" align="right"><br><br>

# SandboxStart

A Windows Sandbox (**WSB**) testing tool for easily testing applications, scripts, and installers in an isolated environment.<br>
Features automatic **WinGet** installation, follow-script-location shortcut, high-DPI compatible UI, **WSB** configuration, script mapping system, dark mode support, Windows Explorer Integration (optional) and customizable test scenarios.

> **Note:** This project was extracted from [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) and made into a standalone tool.<br>
> It depends on the [SandboxTest-Shared](https://github.com/KnifMelti/SandboxTest-Shared) repository as a **Submodule** that also feeds the parent project with new features.

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/GUI.png" alt="GUI Dialog" title="Custom Theme: Hacker Terminal" width="49%"> <img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/List.png" alt="List editor" title="Custom Theme: Hacker Terminal" width="49%" align="top">

## Features

- **Auto-Installation** - prompts to enable Windows Sandbox if not available
- **Follow-script-location shortcut** - automatically creates a shortcut in user's Start Menu on first run:
  - If script folder is moved then `SandboxStart.ps1` must be manually started from the new location again to fix the shortcut
- **Easy-to-use** - interface for configuring sandbox parameters:
  - **DPI-responsive UI** - adds a vertical scrollbar if needed
  - **Folder/File Mapping** - map any folder or select specific file to test:
    - `.exe`,`.msi`,`.msix`,`.cmd`,`.bat`,`.ps1`,`.appx`,`.appxbundle`,`.intunewin`,`.ahk`,`.py`,`.js` or `All Files (*.*)`
  - **Package Lists** - install predefined sets of applications via **WinGet** using custom package lists
  - **Version Control** - select specific **WinGet** version or use pre-release build
  - **Network-only mode** - enable internet access without **WinGet** installation
  - **WSB Configuration** - control network access, memory allocation, and GPU virtualization:
    - **Smart Memory Detection** - automatically detects system **RAM** and offers safe memory options (max 75% of total)
  - **Script Mapping System** - automatic script selection based on file patterns (editable script mappings):
    - **Custom Scripts** - create and save your own scripts for running after sandbox initialization
- **Dark Mode Support** - UI automatically adapts to Windows theme (dark/light mode), **WSB** always syncs with Windows system theme (and syncs to Notepad++ if later installed in sandbox):
  - **Right-click** the main dialog to change **UI** theme (Auto/Light/Dark/Custom) - preference saved to `HKEY_CURRENT_USER\Software\SandboxStart` and doesn't affect **WSB**
- **Windows Explorer Integration** (optional) - add "Test in Windows Sandbox" to File Explorer context menu:
  - **Right-click** the main dialog → "Context Menu Integration" to enable/disable
  - Right-click any file or folder in Windows Explorer (classic context menu) to test directly in sandbox
  - **Windows 11 Note:** Context menu appears in classic menu only (Shift+Right-click or right-click → "Show more options")
- **Updates** - checks and shows notifications if a newer release is available
- **Desktop Shortcuts** - creates useful shortcut links (CMTrace, Sysinternals Live, NirSoft Utilities, CTT Windows Utility, etc.) on the sandbox desktop (downloads assets automatically when started)

## Requirements

- Windows 10/11 **Pro, Enterprise, or Education**
- Windows Sandbox feature (auto-prompt to install if missing)

## Installation

Download, unblock and extract the latest release: [SandboxStart-v#.#.#.#.zip](https://github.com/KnifMelti/SandboxStart/releases/latest)

## Quick Start

1. Right click on `SandboxStart.ps1`
2. Run with PowerShell

This will:
1. Install a shortcut in Start Menu
2. Check if Windows Sandbox is available (prompt to install if not and reboot after prompt - requires elevation)
3. Start from the shortcut
4. Show configuration dialog
5. Launch sandbox with your settings

## Configuration Dialog

The dialog allows you to configure:

### Folder Mapping
- **Map Folder**: select a folder to map into the sandbox
- **Sandbox Folder Name**: name for the folder inside sandbox Desktop

### Read Only
- **R/O**: map the folder as read-only in the sandbox

### File Selection
- **Browse File**: select a specific file to run (automatically maps its parent folder):
  - `.exe`,`.msi`,`.msix`,`.cmd`,`.bat`,`.ps1`,`.appx`,`.appxbundle`,`.intunewin`,`.ahk`,`.py`,`.js` or `All Files (*.*)`

### Package Lists
- **Install Packages**: install predefined sets of applications via **WinGet** using custom package lists
- Useful editable lists are automatically downloaded from the repository

### WinGet Options
- **WinGet Version**: use the drop-down list (dynamically populated) or leave blank for latest
- **Prerelease**: use pre-release of **WinGet**
- **Clean**: clear cached dependencies before starting

### Runtime Options
- **Verbose**: show detailed progress information and wait for keypress before closing **PowerShell** window
- **Skip WinGet installation (network only mode)**: enable networking without installing **WinGet** (only available when **WSB** networking is enabled)
  - Useful for quick browser tests, manual downloads, or network-based tools
  - Startup times:
    - Original WSB without anything at all: ~15s
    - SandboxStart: Full Install ~45s - Network Only/Full Offline ~25-30s
  - User script, desktop shortcuts and all settings still apply

### WSB Configuration
- **Enable Networking**: control network access in sandbox (if unchecked all of the **WinGet** features are skipped - installation/package lists/pre-release/clean cached dependencies)
- **Memory (MB)**: allocate **RAM** to sandbox - dynamically calculated based on your system (max 75% of total RAM)
- **GPU Virtualization**: choose between hardware acceleration (Default/Enable) or software rendering (Disable)

### Script Configuration
- **Script Editor**: **PowerShell** script to run after sandbox initialization:
  - [&#x270E;]: Edit mappings...
  - [Load...]: Load scripts from `wsb\` directory
  - [Save]: Save current script for reuse (not default scripts)
  - [Save as...]: Save current script as new file for reuse
  - [X]: Clear editor

## Script Mapping System

**SandboxStart** automatically selects appropriate scripts based on folder contents using pattern matching defined in `wsb\script-mappings.txt`:

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/Mappings.png" alt="Edit mappings" title="Custom Theme: Hacker Terminal">

### Default Scripts/Mappings

Default scripts are **automatically downloaded from** [GitHub](https://github.com/KnifMelti/SandboxStart/tree/master/Source/assets/scripts) (via [API if the files differ](https://github.com/KnifMelti/SandboxStart/blob/master/CLAUDE.md#github-api-integration-and-caching)) and loaded when a pattern is detected:

| Pattern | Script | Description |
|---------|--------|-------------|
| `InstallWSB.cmd` | Std-WAU.ps1 | Runs install command for **[WAU](https://github.com/Romanitho/Winget-AutoUpdate)** in **WSB** (made in [WAU Settings GUI](https://github.com/KnifMelti/WAU-Settings-GUI)) and opens folder |
| `*.installer.yaml` | Std-Manifest.ps1 | Validates/installs a **WinGet** package from local manifest |
| `*.*` | Std-Install.ps1 | Universal smart installer - detects and runs installers (`Install.*`, `Setup.*`, `Installer.msi`, etc.) with built-in priority, opens Explorer if none found |

> **Note:** Default scripts can't be saved directly in the GUI editor.<br>
> To customize, either create your own script (see Custom Scripts below) or use Custom Override (see Advanced below).

#### Advanced: Custom Override for Default Scripts

You can override **any** default script (Std-*.ps1) by adding `# CUSTOM OVERRIDE` as the first line:

**Method 1: Via GUI (Quick)**
1. Select folder/file to load the default script in editor
2. Add `# CUSTOM OVERRIDE` as the **first line**
3. Modify the script as needed
4. Click **"Save"** button (now enabled for custom scripts)
5. The script is saved and won't be overwritten by GitHub sync

**Method 2: Via Load Button (Full Edit)**
1. Click **"Load..."** button
2. Navigate to `Source\wsb\Std-[ScriptName].ps1`
3. Add `# CUSTOM OVERRIDE` as first line
4. Modify the script
5. Click **"Save"** or **"Save As..."**

**Example:**
```powershell
# CUSTOM OVERRIDE
# My custom installer with logging
# Std-Install.ps1 - Custom version

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SandboxFolderName
)

# Add custom logging
"$(Get-Date) - Starting installation" | Out-File "$env:USERPROFILE\Desktop\install.log"

# ... rest of script ...
```

**Supported Scripts:**
- `Std-Install.ps1` - Custom installer detection logic
- `Std-Manifest.ps1` - Custom manifest validation
- `Std-WAU.ps1` - Custom WAU installation behavior
- `Std-File.ps1` - Custom file type handling (see [CLAUDE.md](CLAUDE.md#creating-a-custom-std-fileps1-handler))

> **Note:** Scripts with `# CUSTOM OVERRIDE` are protected from GitHub sync updates.<br>
> Remove the header or delete the file to revert to defaults.

### Custom Scripts

Create your own scripts in the `wsb\` folder and add/edit mappings to/in `script-mappings.txt`:

```
# Custom mapping example
myapp-*.exe = CustomInstaller.ps1
test-*.zip = ExtractAndTest.ps1
*.* = MyInstaller.ps1
```

## Examples

### Example 1: Test an Installer

1. Browse to folder containing `Setup.exe`
2. Script auto-selects `Std-Install.ps1`
3. Click OK
4. Sandbox launches and runs the installer

### Example 2: Test WinGet Manifest

1. Browse to folder containing a `*.installer.yaml` file
2. Script auto-selects `Std-Manifest.ps1`
3. Click OK
4. Sandbox launches and validates/installs the package from manifest

### Example 3: Custom Script Execution

1. Browse to your test folder
2. Edit script or load custom script
3. Modify **PowerShell** code as needed
4. Click OK
5. Sandbox launches and executes your custom script

### Example 4: Test Specific File

1. Click [File...] to select a specific file:
    1. Change to `All Files (*.*)` if you want to let **Windows** in **WSB** decide how to start it (`.reg`...)
3. Script automatically generates appropriate execution command
4. For `.ahk` or `.py` files: auto-selects required package list if networking enabled
5. For `.intunewin` files: auto-downloads `IntuneWinAppUtilDecoder.exe` in **WSB** so it can be extracted correctly
6. Click OK
7. Sandbox launches, installs dependencies (if needed) and runs the selected file

## Project Structure

```
SandboxStart/
├── SandboxStart.ps1               # Main launcher
├── startmenu-icon.ico             # Icon for shortcut
├── Test-WindowsSandbox.ps1        # WSB detection/installation
├── Update-StartMenuShortcut.ps1   # Manages shortcut creation/updating
├── README.md                      # This file
├── shared/                        # Submodule
|   └── SandboxTest.ps1            # Core sandbox function
|   └── Shared-Helpers.ps1         # Core Helpers
|   └── Show-SandboxTestDialog.ps1 # GUI dialog
└── wsb/                           # Created at first run
    ├── script-mappings.txt        # Pattern→Script mappings (created at first run)
    ├── Std-WAU.ps1                # Default script (created at folder file match)
    ├── Std-Manifest.ps1           # Default script (             "              )
    ├── Std-Install.ps1            # Universal smart installer detector & fallback (*.*)
    ├── Std-File.ps1               # Default script for direct file execution
    └── [custom scripts]           # Your own scripts
```

## For Developers

Source code is located in the `Source/` directory:

```
Source/
├── SandboxStart.ps1               # Main launcher
├── startmenu-icon.ico             # Icon for shortcut
├── Test-WindowsSandbox.ps1        # WSB detection/installation
├── Update-StartMenuShortcut.ps1   # Manages shortcut creation/updating
└── shared/                        # Submodule
    └── SandboxTest.ps1            # Core sandbox function
    └── Shared-Helpers.ps1         # Core Helpers
    └── Show-SandboxTestDialog.ps1 # GUI dialog
```

> **Note:** Release ZIPs extract scripts to the root level (no Source/ folder for end users).

## Troubleshooting

### Windows Sandbox Not Available

**SandboxStart** will automatically prompt to:
1. Enable the Windows Sandbox feature (requires elevation)
2. Restart the computer

**Manual installation of WSB (requires elevation):**

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All
Restart-Computer
```

### Script Not Running in sandbox

- Check that script syntax is valid **PowerShell**
- Verify `$SandboxFolderName` variable is used correctly
- Try with `-Verbose` flag to see detailed execution

### WinGet Installation Fails

- Check internet connection in sandbox
- Try specifying a specific WinGet version
- Use the option: **Clear (cached dependencies)**

### Permission Errors

- Ensure Windows Sandbox feature is fully installed
- Check that mapped folders are accessible

## Use Cases

### For Home Users
- Test downloaded software before installing on main system
- Try out new applications in a safe environment
- Test software from untrusted sources safely
- Experiment with system tweaks without risk

### For Developers
- Test installers without polluting your system
- Test different WinGet package versions
- Validate installation scripts
- Debug installation issues in clean environment

### For IT Professionals
- Test deployment scripts in clean environment
- Validate MSI/EXE installers before rollout
- Check for installation conflicts
- Find out what prerequisites are needed by an installer

### For Package Maintainers
- Test WinGet manifests
- Validate package updates
- Test different installation scenarios
- Verify clean uninstallation

### For Security Professionals
- Analyze suspicious executables in isolated environment
- Test malware behavior safely (sandbox isolation)
- Conduct safe security research and testing
- Investigate potentially unwanted programs (PUPs)
- Use as a lightweight alternative to [FLARE-VM](https://github.com/mandiant/flare-vm) for quick malware analysis

> **Note:** Windows Sandbox does not include Windows Security/Defender, only Microsoft Defender SmartScreen. This allows you to bypass SmartScreen domain restrictions by keeping blocked downloads in the sandbox and copying them to the host system.<br><br>
**Nota bene**: Microsoft's [SandboxTest](https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1) requires a **RW** mapping to:<br>
`%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\` for writing the script based execution inside **WSB**<br>
So, it's not as secure as **FLARE-VM**!


## Additional Resources

- [Windows Sandbox Overview](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
- [WinGet Documentation](https://docs.microsoft.com/windows/package-manager/)
- [Testing a Manifest in Windows Sandbox](https://github.com/microsoft/winget-pkgs/blob/master/doc/README.md#in-windows-sandbox) (original inspiration)
- [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) (parent project)

## Credits

- Based on Microsoft's [SandboxTest](https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1)
- Uses `IntuneWinAppUtilDecoder.exe`: [Oliver Kieselbach](https://oliverkieselbach.com/2022/03/30/ime-debugging-and-intune-win32-app-decoding-part-2/)

## Show Your Support

If you find this tool useful, please consider giving it a star on GitHub!

---

**Made for the Windows development community**
