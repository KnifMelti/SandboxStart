function Update-StartMenuShortcut {
    <#
    .SYNOPSIS
    Ensures SandboxStart.lnk exists in Start Menu with correct path

    .DESCRIPTION
    Checks if SandboxStart.lnk exists in user's Start Menu.
    If it doesn't exist, creates it.
    If it exists, verifies the path matches current script location.
    Uses startmenu-icon.ico from the working directory.

    .PARAMETER WorkingDir
    The working directory where SandboxStart.ps1 is located
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkingDir
    )

    try {
        # Define paths
        $startMenuPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs')
        $shortcutPath = Join-Path $startMenuPath 'SandboxStart.lnk'
        $iconPath = Join-Path $WorkingDir 'startmenu-icon.ico'
        $scriptPath = Join-Path $WorkingDir 'SandboxStart.ps1'

        # Expected target command
        $expectedTarget = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        $expectedArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        # Check if shortcut exists
        $needsUpdate = $false

        if (Test-Path $shortcutPath) {
            # Shortcut exists - verify it points to correct location
            Write-Verbose "Shortcut exists at $shortcutPath, verifying path..."

            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)

                # Check if target and arguments match
                if ($shortcut.TargetPath -ne $expectedTarget -or
                    $shortcut.Arguments -ne $expectedArguments) {
                    Write-Verbose "Shortcut path mismatch detected"
                    Write-Verbose "Current Target: $($shortcut.TargetPath)"
                    Write-Verbose "Expected Target: $expectedTarget"
                    Write-Verbose "Current Arguments: $($shortcut.Arguments)"
                    Write-Verbose "Expected Arguments: $expectedArguments"
                    $needsUpdate = $true
                }
                else {
                    Write-Verbose "Shortcut is up to date"
                }

                # Release COM object
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
            }
            catch {
                Write-Warning "Failed to verify shortcut: $_"
                $needsUpdate = $true
            }
        }
        else {
            # Shortcut doesn't exist
            Write-Verbose "Shortcut does not exist, will create it"
            $needsUpdate = $true
        }

        # Create or update shortcut if needed
        if ($needsUpdate) {
            $wasCreated = -not (Test-Path $shortcutPath)
            Write-Verbose "Creating/updating shortcut at $shortcutPath"

            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $expectedTarget
                $shortcut.Arguments = $expectedArguments
                $shortcut.WorkingDirectory = $WorkingDir
                $shortcut.Description = 'Windows Sandbox Test Launcher'

                # Set icon if it exists
                if (Test-Path $iconPath) {
                    $shortcut.IconLocation = "$iconPath,0"
                }

                $shortcut.Save()
                Write-Verbose "Shortcut created/updated successfully"

                # Release COM object
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

                # Show message if shortcut was created for the first time
                if ($wasCreated) {
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.MessageBox]::Show(
                        "A shortcut to SandboxStart has been created in the Start Menu.`n`nYou can now launch the application from the Start Menu.",
                        "Shortcut Created",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                }
            }
            catch {
                Write-Warning "Failed to create/update shortcut: $_"
                throw
            }
        }
    }
    catch {
        Write-Error "Error in Ensure-StartMenuShortcut: $_"
        throw
    }
}
