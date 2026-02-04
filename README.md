[![Windows Sandbox](https://img.shields.io/badge/Windows%20Sandbox-Required-orange.svg)](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
![GitHub all releases](https://img.shields.io/github/downloads/KnifMelti/SandboxStart/total)
<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/icon.png" alt="Icon" width="128" align="right"><br><br>

# SandboxStart

A Windows Sandbox (**WSB**) testing tool for easily testing applications, scripts, and installers in an isolated environment.

Test software safely before installing on your main system with automatic WinGet installation, customizable test scenarios, and an easy-to-use interface.

<img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/GUI.png" alt="GUI" title="GUI" width="49%" align="top" /><img src="https://github.com/KnifMelti/SandboxStart/blob/master/Source/assets/ListTheme.png" alt="List+Theme" title="List+Theme" width="48%" align="right" />
<br clear="all" />

## Key Features

- **Auto-Installation** - Prompts to enable Windows Sandbox if not available
- **Easy-to-Use Interface** - Configure sandbox parameters with high-DPI responsive UI
- **Smart Script Mapping** - Automatically selects appropriate scripts based on file patterns
- **Package Lists** - Install predefined sets of applications via WinGet
- **Dark Mode Support** - UI and WSB adapts to Windows theme automatically
- **Network-Only Mode** - Enable internet access without WinGet installation (~20-30s faster)
- **WSB Desktop Shortcuts** - Useful tools (CMTrace, Sysinternals, NirSoft, etc.) pre-configured
-  **Right-click context menu**:
    -  **Explorer Integration** - Right-click files/folders to test in sandbox
    -  **Theme Settings** - Custom Theme editor
    -  **Persistent Settings** - Save/reset (autorestores) your preferences

## Requirements

- Windows 10/11 **Pro, Enterprise, or Education**
- Windows Sandbox feature (auto-prompt to install if missing)

## Quick Start

1. **Download** the latest release: [SandboxStart-v#.#.#.#.zip](https://github.com/KnifMelti/SandboxStart/releases/latest)
2. **Unblock** and extract the ZIP file
3. **Right-click** `SandboxStart.ps1` and select "Run with PowerShell"

See [Getting Started](https://github.com/KnifMelti/SandboxStart/wiki/Getting-Started) for detailed installation instructions.

## Documentation

For detailed information, please visit the [**Wiki**](https://github.com/KnifMelti/SandboxStart/wiki):

- [Getting Started](https://github.com/KnifMelti/SandboxStart/wiki/Getting-Started) - Installation and first steps
- [User Guide](https://github.com/KnifMelti/SandboxStart/wiki/User-Guide) - Features and examples
- [Troubleshooting](https://github.com/KnifMelti/SandboxStart/wiki/Troubleshooting) - Common issues and solutions
- [FAQ](https://github.com/KnifMelti/SandboxStart/wiki/FAQ) - Frequently asked questions

## Common Use Cases

### For Home Users
- Test downloaded software before installing on main system
- Try out new applications in a safe environment
- Test software from untrusted sources safely

### For Developers
- Test installers without polluting your system
- Test different WinGet package versions
- Debug installation issues in clean environment

### For IT Professionals
- Test deployment scripts in clean environment
- Validate MSI/EXE installers before rollout
- Find out what prerequisites are needed by an installer

### For Package Maintainers
- Test WinGet manifests
- Validate package updates
- Create custom package lists for testing dependency chains

### For Security Professionals
- Analyze suspicious executables in isolated environment
- Test malware behavior relatively safe (sandbox isolation)
- Conduct safe security research and testing

> **Nota bene:** Microsoft's [SandboxTest](https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1) requires a **R/W** mapping to `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\SandboxTest\` for writing the script based execution inside **WSB**.<br>
For secured testing, use [windows-sandbox-init](https://github.com/jm33-m0/windows-sandbox-init) or [FLARE-VM](https://github.com/mandiant/flare-vm)

## Quick Examples

### Test an Installer
1. Browse to folder containing `Setup.exe`
2. Click OK
3. Sandbox launches and runs the installer

### Test a WinGet Manifest
1. Browse to folder containing `*.installer.yaml`
2. Click OK
3. Sandbox validates/installs the package from manifest

### Install Packages
1. Select a package list (e.g., "Python")
2. Click OK
3. Sandbox installs all packages in the list

> **See the [User Guide](https://github.com/KnifMelti/SandboxStart/wiki/User-Guide) for more examples**

## Need Help?

- See the [User Guide](https://github.com/KnifMelti/SandboxStart/wiki/User-Guide) for features and configuration
- Check [Troubleshooting](https://github.com/KnifMelti/SandboxStart/wiki/Troubleshooting) for common issues
- Read the [FAQ](https://github.com/KnifMelti/SandboxStart/wiki/FAQ) for quick answers

## Release Structure

```
SandboxStart/
├── SandboxStart.ps1               # Main launcher
├── startmenu-icon.ico             # Icon for shortcut
├── Test-WindowsSandbox.ps1        # WSB detection/installation
├── Update-StartMenuShortcut.ps1   # Manages shortcut creation/updating
├── shared/                        # Submodule (SandboxTest-Shared)
│   ├── SandboxTest.ps1            # Core sandbox function
│   ├── Shared-Helpers.ps1         # Core helpers
│   └── Show-SandboxTestDialog.ps1 # GUI dialog
└── wsb/                           # Created at first run
    ├── script-mappings.txt        # Pattern→Script mappings
    ├── config.ini                 # Package lists/extensions configuration
    ├── AutoInstall.txt            # Special auto-install list
    ├── Std-*.ps1                  # Default scripts (auto-downloaded)
    ├── Std-*.txt                  # Default package lists (auto-downloaded)
    └── [custom files]             # Your own scripts and lists
```

## Contributing

Contributions are (maybe) welcome! See [CLAUDE.md](CLAUDE.md) for developer information.

## Additional Resources

- [Windows Sandbox Overview](https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview)
- [WinGet Documentation](https://docs.microsoft.com/windows/package-manager/)
- [WAU-Settings-GUI](https://github.com/KnifMelti/WAU-Settings-GUI) (parent project)
- [SandboxTest-Shared](https://github.com/KnifMelti/SandboxTest-Shared) (submodule repository)

## Credits

- Based on Microsoft's [SandboxTest](https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1)
- Provides downloadable tools in WSB: CMTrace, IntuneWinAppUtilDecoder, CTT Windows Utility, AdvancedRun, UninstallView

## Show Your Support

If you find this tool useful, please consider giving it a star on GitHub!

---

**Made for the Windows development community**
