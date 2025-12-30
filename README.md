[![Windows Sandbox](https://img.shields.io/badge/Windows%20Sandbox-Required-orange.svg)](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/SandboxStart/total)
<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/icon.png" alt="Icon" width="128" align="right"><br><br>

# SandboxStart

A Windows Sandbox (**WSB**) testing tool for easily testing applications, scripts, and installers in an isolated environment.<br>
Features automatic WinGet installation, follow-script-location shortcut, WSB configuration, script mapping system, and customizable test scenarios.

> **Note:** This project was extracted from [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) and made into a standalone tool.<br>
> It depends on the [SandboxTest-Shared](https://github.com/KnifMelti/SandboxTest-Shared) repository as a **Submodule**.

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/GUI.png" alt="GUI Dialog" title="Custom Theme Hacker Terminal" width="49%"> <img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/List.png" alt="List editor" title="Custom Theme Hacker Terminal" width="49%" align="top">

## Features

- **Auto-Installation** - Prompts to enable Windows Sandbox if not available
- **Follow-script-location shortcut** - Automatically creates/updates a shortcut in user's Start Menu on first run/if script folder is moved (then `SandboxStart.ps1` must be manually started from the new location again)
- **GUI Dialog** - Easy-to-use interface for configuring sandbox parameters:
  - **Folder/File Mapping** - Map any folder or select specific file to test
  - **Package Lists** - Install predefined sets of applications via WinGet using custom package lists
  - **Version Control** - Select specific WinGet version or use pre-release build
  - **WSB Configuration** - Control network access, memory allocation, and GPU virtualization:
    - **Smart Memory Detection** - Automatically detects system RAM and offers safe memory options (max 75% of total)
  - **Script Mapping System** - Automatic script selection based on file patterns (editable script mappings):
    - **Custom Scripts** - Create and save your own sandbox initialization scripts
- **Updates** check/notifications
- **Dark Mode Support** - GUI automatically adapts to Windows theme (dark/light mode), sandbox always syncs with Windows system theme (and Notepad++ if later installed in **WSB**)
  - **Tip**: Right-click the main dialog to change GUI theme (Auto/Light/Dark/Custom) - preference persists during session and doesn't affect sandbox
- **Desktop Shortcuts** - Creates useful shortcut links (CMTrace, Sysinternals Live, NirSoft Utilities, CTT Windows Utility, etc.) on the sandbox desktop

## Requirements

- Windows 10/11 **Pro, Enterprise, or Education**
- Windows Sandbox feature (auto-prompt to install if missing)

## Installation

Download, unblock and extract the latest release: [SandboxStart-v#.#.#.#.zip](https://github.com/KnifMelti/SandboxStart//releases/latest)

## Quick Start

1. Right click on `SandboxStart.ps1`
2. Run with PowerShell

This will:
1. Install a shortcut in Start Menu
2. Check if Windows Sandbox is available (prompt to install if not and reboot after prompt)
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
  - [&#x270E;]: Edit mappings...
  - [Load...]: Load scripts from `wsb\` directory
  - [Save]: Save current script for reuse (not default scripts)
  - [Save as...]: Save current script as new file for reuse
  - [X]: Clear editor

## Script Mapping System

SandboxStart automatically selects appropriate scripts based on folder contents using pattern matching defined in `wsb\script-mappings.txt`:

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/Mappings.png" alt="Edit mappings" title="Custom Theme Hacker Terminal">

### Default Scripts/Mappings

Default scripts are **automatically downloaded from** [GitHub](https://github.com/KnifMelti/SandboxStart/tree/master/Source/assets/scripts) (via API if the files differ) and loaded when a pattern is detected:

| Pattern | Script | Description |
|---------|--------|-------------|
| `InstallWSB.cmd` | Std-WAU.ps1 | Runs install command for **[WAU](https://github.com/Romanitho/Winget-AutoUpdate)** in **WSB** (from [WAU Settings GUI](https://github.com/KnifMelti/WAU-Settings-GUI)) and opens folder |
| `*.installer.yaml` | Std-Manifest.ps1 | Validates/installs a **WinGet** package from local manifest |
| `*.*` | Std-Install.ps1 | Universal smart installer - detects and runs installers (`Install.*`, `Setup.*`, `Installer.msi`, etc.) with built-in priority, opens Explorer if none found |

> **Note:** Default scripts can't be saved in the GUI, only saved as...<br>
> To customize behavior, create your own script and add/edit the mappings (see Custom Scripts below).

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

In dialog:
1. Browse to folder containing `Setup.exe`
2. Script auto-selects "Std-Install.ps1"
3. Click OK
4. Sandbox launches and runs the installer

### Example 2: Test WinGet Manifest

In dialog:
1. Browse to folder containing a `*.installer.yaml` file
2. Script auto-selects "Std-Manifest.ps1"
3. Click OK
4. Sandbox launches and validates/installs the package from manifest

### Example 3: Custom Script Execution

In dialog:
1. Browse to your test folder
2. Edit script or load custom script
3. Modify PowerShell code as needed
4. Click OK
5. Sandbox executes your custom script

### Example 4: Test Specific File

In dialog:
1. Click "File..." to select a specific file (`.exe`, `.msi`, `.cmd`, `.bat`, `.ps1`, `.ahk`, `.py`, `.js`)
2. Script automatically generates appropriate execution command
3. For `.ahk` or `.py` files: Auto-selects required package list if networking enabled
4. Click OK
5. Sandbox installs dependencies (if needed) and runs the selected file

> **Note:** To enable auto-installation for `.ahk` or `.py` files, create package list files:
> - `wsb\AHK.txt` containing `AutoHotkey.AutoHotkey`
> - `wsb\Python.txt` containing `Python.Python.3.13`

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
- Use the option: **Clear (cached dependencies)**

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
