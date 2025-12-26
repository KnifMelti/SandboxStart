[![Windows Sandbox](https://img.shields.io/badge/Windows%20Sandbox-Required-orange.svg)](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/SandboxStart/total)
<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/icon.png" alt="Icon" width="128" align="right"><br><br>

# SandboxStart

A Windows Sandbox (**WSB**) testing tool for easily testing applications, scripts, and installers in an isolated environment.<br>
Features automatic WinGet installation, Start Menu shortcut, WSB configuration, script mapping system, and customizable test scenarios.

> **Note:** This project was extracted from [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) and made into a standalone tool.<br>
> It depends on the [SandboxTest-Shared](https://github.com/KnifMelti/SandboxTest-Shared) repository as a **Submodule**.

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/GUI.png" alt="GUI Dialog" width="49%"> <img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/List.png" alt="List editor" width="49%" align="top">

## Features

- **Auto-Installation** - Prompts to enable Windows Sandbox if not available
- **Start Menu Shortcut** - Automatically creates/updates a shortcut in user's Start Menu on first run and if script folder is moved (then `SandboxStart.ps1` must be manually started from the new location)
- **GUI Dialog** - Easy-to-use interface for configuring sandbox parameters:
  - **Folder/File Mapping** - Map any folder or select specific file to test
  - **Package Lists** - Install predefined sets of applications via WinGet using custom package lists
  - **Version Control** - Select specific WinGet version or use pre-release build
  - **WSB Configuration** - Control network access, memory allocation, and GPU virtualization:
    - **Smart Memory Detection** - Automatically detects system RAM and offers safe memory options (max 75% of total)
  - **Script Mapping System** - Automatic script selection based on file patterns (editable script mappings):
    - **Custom Scripts** - Create and save your own sandbox initialization scripts
- **Dark Mode Sync** - Automatically syncs dark mode from host to Windows Sandbox (and Notepad++ if later installed in **WSB**)
- **Desktop Shortcuts** - Creates useful shortcut links (CMTrace, Sysinternals Live, NirSoft Utilities, CTT Windows Utility, etc.) on the sandbox desktop

## Requirements

- Windows 10/11 **Pro, Enterprise, or Education**
- Windows Sandbox feature (auto-prompt to install if missing)

## Installation

Download, unblock and extract the latest release: [SandboxStart-v#.#.#.#.zip](https://github.com/KnifMelti/SandboxStart//releases/latest)

## Quick Start

```powershell
.\SandboxStart.ps1
```

This will:
1. Check if Windows Sandbox is available (prompt to install if not and restart after prompt)
2. Install a shortcut in Start Menu
3. Start from the shortcut
4. Show configuration dialog
5. Launch sandbox with your settings

## Configuration Dialog

The GUI dialog allows you to configure:

### Folder Mapping
- **Map Folder**: Select a folder to map into the sandbox
- **Sandbox Folder Name**: Name for the folder inside sandbox Desktop

### File Selection
- **Browse File**: Select a specific file to run (automatically maps its parent folder)

### Package Lists
- **Install Package Lists**: Install predefined sets of applications via WinGet using custom package lists

### WinGet Options
- **WinGet Version**: Use the drop-down list (dynamically populated) or leave blank for latest
- **Prerelease**: Use pre-release of WinGet
- **Clean**: Clear cached dependencies before starting

### Runtime Options
- **Verbose**: Show detailed progress information and wait for keypress before closing PS window

### WSB Configuration
- **Enable Networking**: Control network access in sandbox (required for WinGet, if unchecked WinGet handling is skipped)
- **Memory (MB)**: Allocate RAM to sandbox - dynamically calculated based on your system (max 75% of total RAM)
- **GPU Virtualization**: Choose between hardware acceleration (Default/Enable) or software rendering (Disable)

### Script Configuration
- **Script Editor**: PowerShell script to run after sandbox initialization:
  - **[Load...]**: Load saved custom scripts from `wsb\` directory
  - **[Save]**: Save current script for reuse
  - **[Save as...]**: Save current script as new file for reuse
  - **[...]**: Edit mappings...

## Script Mapping System

SandboxStart automatically selects appropriate scripts based on folder contents using pattern matching defined in `wsb\script-mappings.txt`:

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/Mappings.png" alt="Edit mappings">

### Default Mappings/Scripts

Relevant script is automatically created in the `wsb\` folder (then editable) when a pattern is detected:

| Pattern | Script | Description |
|---------|--------|-------------|
| `InstallWSB.cmd` | InstallWSB.ps1 | Runs install command for **[WAU](https://github.com/Romanitho/Winget-AutoUpdate)** in **WSB** (from [WAU Settings GUI](https://github.com/KnifMelti/WAU-Settings-GUI)) and opens folder |
| `*.installer.yaml` | WinGetManifest.ps1 | Validates/installs **WinGet** packages from local manifest |
| `Install.*` | Installer.ps1 | Searches for and runs common installer files |
| `*.*` | Explorer.ps1 | Opens mapped folder in Explorer (fallback) |

### Custom Scripts

Create your own scripts in the `wsb\` folder and add mappings to `script-mappings.txt`:

```
# Custom mapping example
myapp-*.exe = CustomInstaller.ps1
test-*.zip = ExtractAndTest.ps1
```

All custom scripts have access to the `$SandboxFolderName` variable which contains the full path to the mapped folder on the sandbox Desktop.

## Examples

### Example 1: Test an Installer

```powershell
.\SandboxStart.ps1
```

In dialog:
1. Browse to folder containing `Setup.exe`
2. Script auto-selects "Installer.ps1"
3. Click OK
4. Sandbox launches and runs the installer

### Example 2: Test WinGet Manifest

```powershell
.\SandboxStart.ps1
```

In dialog:
1. Browse to folder containing `.installer.yaml` files
2. Script auto-selects "WinGetManifest.ps1"
3. Click OK
4. Sandbox launches and installs package from manifest

### Example 3: Custom Script Execution

```powershell
.\SandboxStart.ps1
```

In dialog:
1. Browse to your test folder
2. Edit script or load custom script
3. Modify PowerShell code as needed
4. Click OK
5. Sandbox executes your custom script

### Example 4: Test Specific File

```powershell
.\SandboxStart.ps1
```

In dialog:
1. Click "File..." to select a specific `.exe`, `.bat` `.cmd`, `.js` or `.ps1`q 
2. Script automatically generates appropriate execution command
3. Click OK
4. Sandbox runs the selected file

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
|   └── Show-SandboxTestDialog.ps1 # GUI dialog
└── wsb/                           # Created at first run
    ├── script-mappings.txt        # Pattern→Script mappings (created at first run)
    ├── InstallWSB.ps1             # Default script (created at folder file match)
    ├── WinGetManifest.ps1         # Default script (             "              )
    ├── Installer.ps1              # Default script (             "              )
    ├── Explorer.ps1               # Default script (        fallback *.*        )
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
    └── Show-SandboxTestDialog.ps1 # GUI dialog
```

To run from the repository:

```powershell
cd Source
.\SandboxStart.ps1
```

**Note:** Release ZIPs extract scripts to the root level (no Source/ folder for end users).

## Troubleshooting

### Windows Sandbox Not Available

SandboxStart will automatically prompt to:
1. Enable the Windows Sandbox feature
2. Restart the computer

**Manual installation of WSB:**

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All
Restart-Computer
```

### Script Not Running in Sandbox

- Check that script syntax is valid PowerShell
- Verify `$SandboxFolderName` variable is used correctly
- Try with `-Verbose` flag to see detailed execution

### WinGet Installation Fails

- Check internet connection in sandbox
- Try specifying a specific WinGet version
- Use `-Clean` flag to clear cached dependencies

### Permission Errors

- Ensure Windows Sandbox feature is fully installed
- Check that mapped folders are accessible

## Use Cases

### For Developers
- Test installers without polluting your system
- Test different WinGet package versions
- Validate installation scripts
- Debug installation issues in clean environment

### For IT Professionals
- Test deployment scripts in clean environment
- Validate MSI/EXE installers before rollout
- Check for installation conflicts
- Test software behavior with different registry settings

### For Package Maintainers
- Test WinGet manifests
- Validate package updates
- Test different installation scenarios
- Verify clean uninstallation

## Additional Resources

- [Windows Sandbox Overview](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
- [WinGet Documentation](https://docs.microsoft.com/windows/package-manager/)
- [Testing a Manifest in Windows Sandbox](https://github.com/microsoft/winget-pkgs/blob/master/doc/README.md#in-windows-sandbox) (Original inspiration)
- [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) (Parent project)

## Credits

- Based on Microsoft's [SandboxTest](https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1)

## Show Your Support

If you find this tool useful, please consider giving it a star on GitHub!

---

**Made for the Windows development community**
