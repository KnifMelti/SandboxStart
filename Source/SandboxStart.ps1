<#
.SYNOPSIS
    Windows Sandbox Test Launcher

.DESCRIPTION
    A GUI tool for easily testing applications, scripts, and installers in Windows Sandbox.
    Provides automated WinGet installation and customizable script execution.

.EXAMPLE
    .\SandboxStart.ps1
    Launches the GUI dialog for configuring sandbox parameters

.NOTES
    Requires Windows 10/11 Pro, Enterprise, or Education
    Windows Sandbox feature must be enabled
#>

#Requires -Version 5.1

param(
    [Parameter(Mandatory=$false)]
    [string]$FolderPath,

    [Parameter(Mandatory=$false)]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'
$Script:WorkingDir = $PSScriptRoot

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load required functions
. "$WorkingDir\Test-WindowsSandbox.ps1"
. "$WorkingDir\Update-StartMenuShortcut.ps1"

# Ensure Start Menu shortcut exists and is up to date
$shortcutNeedsRestart = Update-StartMenuShortcut -WorkingDir $WorkingDir

# If shortcut was created or updated, restart from the shortcut
# BUT: Don't restart if we were called from context menu (with FolderPath/FilePath parameters)
$calledFromContextMenu = ($FolderPath -or $FilePath)

if ($shortcutNeedsRestart -and -not $calledFromContextMenu) {
    $shortcutPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs\SandboxStart.lnk')

    # Check if this is first-time creation (shortcut didn't exist before)
    # We detect this by checking if we were started from the shortcut or directly
    $startedFromShortcut = $MyInvocation.InvocationName -match 'SandboxStart\.lnk'

    if (-not $startedFromShortcut) {
        # Show dialog only on first-time creation
        if (Test-Path $shortcutPath) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $wasJustCreated = $shortcut.Arguments -match [regex]::Escape($WorkingDir)
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

            if ($wasJustCreated) {
                [System.Windows.Forms.MessageBox]::Show(
                    "A shortcut to SandboxStart has been created in the Start Menu.`n`nThe script will now restart to display the custom icon in taskbar.",
                    "Shortcut Created",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
        }

        # Launch from the shortcut and exit (both for new and updated shortcuts)
        Start-Process -FilePath $shortcutPath
        exit
    }
}

function Start-SandboxApplication {
    <#
    .SYNOPSIS
    Main application entry point
    #>
    
    try {
        # Check Windows Sandbox availability
        $wsbReady = Test-WindowsSandbox

        if (-not $wsbReady) {
            # User cancelled or feature couldn't be enabled
            throw "Windows Sandbox is required but not available."
        }

        # Set script-scoped variables for Show-SandboxTestDialog to pick up
        if ($FolderPath) { $script:InitialFolderPath = $FolderPath }
        if ($FilePath) { $script:InitialFilePath = $FilePath }

        . "$WorkingDir\shared\SandboxTest.ps1"
        . "$WorkingDir\shared\Shared-Helpers.ps1"
        . "$WorkingDir\shared\Show-SandboxTestDialog.ps1"
        
    }
    catch {
        # Only show error dialog if it's not the "Sandbox not available" message (already shown graphically)
        if ($_.Exception.Message -ne "Windows Sandbox is required but not available.") {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        exit 1
    }
}

# Main execution
Start-SandboxApplication
