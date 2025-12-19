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
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$Script:WorkingDir = $PSScriptRoot

# Load required functions
. "$PSScriptRoot\Test-WindowsSandbox.ps1"
. "$PSScriptRoot\Show-SandboxTestDialog.ps1"
. "$PSScriptRoot\SandboxTest.ps1"

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
            Write-Host "Windows Sandbox is required but not available. Exiting." -ForegroundColor Yellow
            exit 1
        }
        
        # Show configuration dialog in a loop to allow re-entry if version is invalid
        while ($true) {
            $dialogResult = Show-SandboxTestDialog
            
            if (-not $dialogResult -or $dialogResult.DialogResult -ne 'OK') {
                # User cancelled the dialog
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                exit 0
            }
            
            # Validate WinGet version if one was specified (skip validation if Pre-release is checked)
            $versionValid = $true
            if (![string]::IsNullOrWhiteSpace($dialogResult.WinGetVersion) -and -not $dialogResult.Prerelease) {
                Write-Verbose "Validating WinGet version: $($dialogResult.WinGetVersion)"
                $versionExists = Test-WinGetVersion -Version $dialogResult.WinGetVersion
                
                if (-not $versionExists) {
                    $result = [System.Windows.Forms.MessageBox]::Show(
                        "The specified WinGet version '$($dialogResult.WinGetVersion)' was not found in the GitHub repository.`n`nPlease choose an action:`n`nClick 'OK' to return to the configuration dialog and select a different version.`nClick 'Cancel' to exit the application.",
                        "Invalid WinGet Version",
                        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    
                    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                        # Continue the loop to show the dialog again
                        $versionValid = $false
                    } else {
                        # User chose Cancel - exit the script
                        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                        exit 0
                    }
                }
            }
            
            # If version is valid (or not specified), proceed with SandboxTest
            if ($versionValid) {
                break
            }
        }
        
        # Build parameters for SandboxTest
        $sandboxParams = @{
            MapFolder = $dialogResult.MapFolder
            SandboxFolderName = $dialogResult.SandboxFolderName
            Script = $dialogResult.Script
        }
        
        # Add optional parameters if they have values
        if (![string]::IsNullOrWhiteSpace($dialogResult.WinGetVersion)) {
            $sandboxParams.WinGetVersion = $dialogResult.WinGetVersion
        }
        if ($dialogResult.Prerelease) { $sandboxParams.Prerelease = $true }
        if ($dialogResult.Clean) { $sandboxParams.Clean = $true }
        if ($dialogResult.Async) { $sandboxParams.Async = $true }
        if ($dialogResult.Verbose) { $sandboxParams.Verbose = $true }
        
        # Execute SandboxTest
        Write-Host "`nLaunching Windows Sandbox..." -ForegroundColor Cyan
        SandboxTest @sandboxParams
        
        # Wait for key press if requested
        if ($dialogResult.Wait) {
            Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        exit 0
    }
    catch {
        Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
