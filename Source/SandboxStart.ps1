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

$ErrorActionPreference = 'Stop'
$Script:WorkingDir = $PSScriptRoot

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load required functions
. "$WorkingDir\Test-WindowsSandbox.ps1"
. "$WorkingDir\Ensure-StartMenuShortcut.ps1"

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

        # Ensure Start Menu shortcut exists and is up to date
        Update-StartMenuShortcut -WorkingDir $WorkingDir

        . "$WorkingDir\shared\SandboxTest.ps1"
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
