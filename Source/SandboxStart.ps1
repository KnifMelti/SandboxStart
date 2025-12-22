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
if (Test-Path "$WorkingDir\shared\SandboxTest.ps1") {
    . "$WorkingDir\shared\SandboxTest.ps1"
} else {
    . "$WorkingDir\SandboxTest.ps1"
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

        if (Test-Path "$WorkingDir\shared\Show-SandboxTestDialog.ps1") {
            . "$WorkingDir\shared\Show-SandboxTestDialog.ps1"
        } else {
            . "$WorkingDir\Show-SandboxTestDialog.ps1"
        }
        
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

function Test-WinGetVersion {
    <#
    .SYNOPSIS
    Validates that a WinGet version exists
    
    .PARAMETER Version
    Version string to validate (e.g., "1.7.10514", "v1.7.10514")
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    try {
        $releasesUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
        $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing -ErrorAction Stop
        
        # Normalize version (remove 'v' prefix if present)
        $normalizedVersion = $Version.TrimStart('v')
        
        # Match against tag_name (which may or may not have 'v' prefix)
        $versionPattern = '^v?' + [regex]::Escape($normalizedVersion)
        $matchingRelease = $releases | Where-Object { $_.tag_name -match $versionPattern } | Select-Object -First 1
        
        if ($matchingRelease) {
            Write-Verbose "Found matching release: $($matchingRelease.tag_name)"
            return $true
        } else {
            Write-Verbose "No matching release found for version: $Version"
            return $false
        }
    }
    catch {
        Write-Warning "Failed to validate WinGet version: $($_.Exception.Message)"
        # On error, assume version might be valid (fail open)
        return $true
    }
}

# Main execution
Start-SandboxApplication
