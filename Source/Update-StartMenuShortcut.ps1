function Update-StartMenuShortcut {
	<#
	.SYNOPSIS
	Ensures SandboxStart.lnk exists in Start Menu with correct path

	.DESCRIPTION
	Checks if SandboxStart.lnk exists in user's Start Menu.
	If it doesn't exist, creates it and returns true (indicating it was created to restart from it).
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
		$wasCreated = $false

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

	# ALWAYS ensure uninstall shortcut exists and is up to date
	# This ensures existing installations also get the uninstall shortcut
	$uninstallShortcutPath = Join-Path $startMenuPath 'SandboxStart - Uninstall.lnk'
	$expectedUninstallArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& {Add-Type -AssemblyName System.Windows.Forms; . '$WorkingDir\Update-StartMenuShortcut.ps1'; Uninstall-SandboxStart}`""

	$uninstallNeedsUpdate = $false

	if (Test-Path $uninstallShortcutPath) {
		# Verify uninstall shortcut points to correct location
		Write-Verbose "Uninstall shortcut exists, verifying path..."

		try {
			$shell = New-Object -ComObject WScript.Shell
			$uninstallShortcut = $shell.CreateShortcut($uninstallShortcutPath)

			# Check if arguments match (contains correct working directory path)
			if ($uninstallShortcut.Arguments -ne $expectedUninstallArguments) {
				Write-Verbose "Uninstall shortcut path mismatch detected"
				Write-Verbose "Current Arguments: $($uninstallShortcut.Arguments)"
				Write-Verbose "Expected Arguments: $expectedUninstallArguments"
				$uninstallNeedsUpdate = $true
			}

			[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
		}
		catch {
			Write-Warning "Failed to verify uninstall shortcut: $_"
			$uninstallNeedsUpdate = $true
		}
	}
	else {
		# Uninstall shortcut doesn't exist
		Write-Verbose "Uninstall shortcut does not exist, will create it"
		$uninstallNeedsUpdate = $true
	}

	if ($uninstallNeedsUpdate) {
		Write-Verbose "Creating/updating uninstall shortcut at $uninstallShortcutPath"

		try {
			$shell = New-Object -ComObject WScript.Shell

			$uninstallShortcut = $shell.CreateShortcut($uninstallShortcutPath)
			$uninstallShortcut.TargetPath = $expectedTarget
			$uninstallShortcut.Arguments = $expectedUninstallArguments
			$uninstallShortcut.WorkingDirectory = $WorkingDir
			$uninstallShortcut.Description = 'Uninstall SandboxStart integration'

			if (Test-Path $iconPath) {
				$uninstallShortcut.IconLocation = "$iconPath,0"
			}

			$uninstallShortcut.Save()
			Write-Verbose "Uninstall shortcut created/updated successfully"

			# Release COM object
			[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
		}
		catch {
			Write-Warning "Failed to create/update uninstall shortcut: $_"
			# Don't throw - uninstall shortcut is not critical for main functionality
		}
	}
	# Return true ONLY if shortcut was created for the first time
	# (not when updated - that would cause restart dialog every time script moves)
	return $wasCreated
}

function Test-ContextMenuIntegration {
	<#
	.SYNOPSIS
	Check if context menu integration is currently installed

	.OUTPUTS
	Boolean - True if installed, False otherwise
	#>

	# Use reg.exe instead of Test-Path to avoid performance issues with HKCU:\Software\Classes\*
	$folderKeyReg = 'HKCU\Software\Classes\Directory\shell\SandboxStart'
	$fileKeyReg = 'HKCU\Software\Classes\*\shell\SandboxStart'
	$driveKeyReg = 'HKCU\Software\Classes\Drive\shell\SandboxStart'

	$folderExists = $null -ne (reg.exe query "$folderKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' })
	$fileExists = $null -ne (reg.exe query "$fileKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' })
	$driveExists = $null -ne (reg.exe query "$driveKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' })

	return ($folderExists -and $fileExists -and $driveExists)
}

function Uninstall-SandboxStart {
	<#
	.SYNOPSIS
	Completely removes SandboxStart integration from Windows

	.DESCRIPTION
	Removes Start Menu shortcuts and context menu integration (if installed)
	#>
	[CmdletBinding()]
	param()

	try {
		# Ask for confirmation first
		$result = [System.Windows.Forms.MessageBox]::Show(
			"This will completely remove SandboxStart integration from Windows:`n`n  - Start Menu shortcuts`n  - Registry settings`n  - Context menu entries (if installed)`n`nWorking files will be kept and must be deleted manually if desired.`n`nContinue?",
			"Confirm Uninstall",
			[System.Windows.Forms.MessageBoxButtons]::OKCancel,
			[System.Windows.Forms.MessageBoxIcon]::Warning
		)

		if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
			return $false
		}

		$startMenuPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs')
		$mainShortcut = Join-Path $startMenuPath 'SandboxStart.lnk'
		$uninstallShortcut = Join-Path $startMenuPath 'SandboxStart - Uninstall.lnk'

		# Remove shortcuts
		$removed = @()
		if (Test-Path $mainShortcut) {
			Remove-Item $mainShortcut -Force
			$removed += "Start Menu shortcut"
		}
		if (Test-Path $uninstallShortcut) {
			Remove-Item $uninstallShortcut -Force
			$removed += "Uninstall shortcut"
		}

		# Remove registry key HKEY_CURRENT_USER\Software\SandboxStart if it exists
		$sandboxStartKeyReg = 'HKCU\Software\SandboxStart'
		$keyCheck = reg.exe query "$sandboxStartKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' }
		if ($null -ne $keyCheck) {
			$null = reg.exe delete "$sandboxStartKeyReg" /f 2>&1
			Write-Verbose "Removed SandboxStart registry key"
			$removed += "Registry settings"
		}

		# Remove context menu integration (check each key independently using reg.exe for performance)
		$folderKeyReg = 'HKCU\Software\Classes\Directory\shell\SandboxStart'
		$fileKeyReg = 'HKCU\Software\Classes\*\shell\SandboxStart'
		$driveKeyReg = 'HKCU\Software\Classes\Drive\shell\SandboxStart'

		$contextMenuRemoved = $false

		# Check and remove folder context menu
		$folderCheck = reg.exe query "$folderKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' }
		if ($null -ne $folderCheck) {
			$null = reg.exe delete "$folderKeyReg" /f 2>&1
			Write-Verbose "Removed folder context menu registry key"
			$contextMenuRemoved = $true
		}

		# Check and remove file context menu
		$fileCheck = reg.exe query "$fileKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' }
		if ($null -ne $fileCheck) {
			$null = reg.exe delete "$fileKeyReg" /f 2>&1
			Write-Verbose "Removed file context menu registry key"
			$contextMenuRemoved = $true
		}

		# Check and remove drive context menu
		$driveCheck = reg.exe query "$driveKeyReg" 2>&1 | Where-Object { $_ -match 'SandboxStart' }
		if ($null -ne $driveCheck) {
			$null = reg.exe delete "$driveKeyReg" /f 2>&1
			Write-Verbose "Removed drive context menu registry key"
			$contextMenuRemoved = $true
		}

		if ($contextMenuRemoved) {
			$removed += "Context menu integration"
		}

		# Build result message
		if ($removed.Count -eq 0) {
			$message = "No SandboxStart components found to remove."
		}
		else {
			$message = "SandboxStart has been uninstalled.`n`nRemoved:"
			foreach ($item in $removed) {
				$message += "`n  - $item"
			}
			$message += "`n`nWorking directory files were kept.`nYou can manually delete the SandboxStart folder if desired."
		}

		[System.Windows.Forms.MessageBox]::Show(
			$message,
			"Uninstall Complete",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)

		return $true
	}
	catch {
		Write-Error "Failed to uninstall SandboxStart: $_"

		[System.Windows.Forms.MessageBox]::Show(
			"Failed to uninstall: $($_.Exception.Message)",
			"Uninstall Failed",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Error
		)

		return $false
	}
}