<#
.SYNOPSIS
	Windows Sandbox Detection and Installation Helper

.DESCRIPTION
	Checks if Windows Sandbox is installed and enabled.
	Prompts user to enable the feature if not available.
	Handles pending reboot scenarios.
#>

function Test-WindowsSandbox {
	<#
	.SYNOPSIS
	Checks Windows Sandbox availability and offers to enable if needed
	
	.DESCRIPTION
	Performs the following checks:
	1. Checks if WindowsSandbox.exe exists
	2. If missing, checks feature state
	3. If enabled but exe missing -> Prompt for reboot
	4. If disabled -> Offer to enable feature
	
	.OUTPUTS
	Boolean - True if Windows Sandbox is ready to use, False otherwise
	
	.EXAMPLE
	if (Test-WindowsSandbox) {
		# Proceed with sandbox operations
	}
	#>
	
	[CmdletBinding()]
	[OutputType([bool])]
	param()
	
	try {
		$sandboxExe = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"

		if (Test-Path $sandboxExe) {
			# Windows Sandbox executable exists - ready to use
			Write-Verbose "Windows Sandbox is available at: $sandboxExe"
			return $true
		}

		# Executable missing - need to check feature state (requires admin rights)
		Write-Verbose "WindowsSandbox.exe not found, checking feature state..."

		# Check for admin rights before attempting to query feature state
		$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

		if (-not $isAdmin) {
			$adminMessage = "Windows Sandbox is not installed.`n`n"
			$adminMessage += "Administrator privileges are required to check and enable the Windows Sandbox feature.`n`n"
			$adminMessage += "Please restart this script as administrator."

			[void][System.Windows.Forms.MessageBox]::Show(
				$adminMessage,
				"Administrator Privileges Required",
				[System.Windows.Forms.MessageBoxButtons]::OK,
				[System.Windows.Forms.MessageBoxIcon]::Error
			)

			return $false
		}

		$wsbFeature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -ErrorAction SilentlyContinue
		
		if ($wsbFeature -and $wsbFeature.State -eq 'Enabled') {
			# Feature enabled but exe missing -> Pending reboot
			Write-Warning "Windows Sandbox feature is enabled but executable is missing (restart required)"
			
			$message = "Windows Sandbox feature is enabled but the executable is missing:`n$sandboxExe`n`n"
			$message += "A restart is required before it can be used.`n`nRestart now?"
			
			$result = [System.Windows.Forms.MessageBox]::Show(
				$message,
				"Restart Required",
				[System.Windows.Forms.MessageBoxButtons]::OKCancel,
				[System.Windows.Forms.MessageBoxIcon]::Information
			)

			if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
				Restart-Computer -Force
			}
			
			return $false
		}
		else {
			# Feature not enabled - offer to enable it
			Write-Warning "Windows Sandbox is not enabled"
			
			$message = "Windows Sandbox is not enabled (executable missing:`n$sandboxExe).`n`n"
			$message += "Enable the feature now? (Restart required after enabling)"
			
			$result = [System.Windows.Forms.MessageBox]::Show(
				$message,
				"Windows Sandbox Not Enabled",
				[System.Windows.Forms.MessageBoxButtons]::OKCancel,
				[System.Windows.Forms.MessageBoxIcon]::Question
			)

			if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
				return $false
			}
			
			try {
				Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart -ErrorAction Stop | Out-Null
				
				$message = "Feature enabled. A restart is required before Windows Sandbox can be used.`n`nRestart now?"
				
				$rebootResult = [System.Windows.Forms.MessageBox]::Show(
					$message,
					"Restart Required",
					[System.Windows.Forms.MessageBoxButtons]::YesNo,
					[System.Windows.Forms.MessageBoxIcon]::Question
				)

				if ($rebootResult -eq [System.Windows.Forms.DialogResult]::Yes) {
					Restart-Computer -Force
				}
				
				return $false
			}
			catch {
				$errorMsg = "Failed to enable Windows Sandbox: $($_.Exception.Message)"
				Write-Error $errorMsg
				
				[System.Windows.Forms.MessageBox]::Show(
					$errorMsg,
					"Enable Failed",
					[System.Windows.Forms.MessageBoxButtons]::OK,
					[System.Windows.Forms.MessageBoxIcon]::Error
				)
				
				return $false
			}
		}
	}
	catch {
		$errorMsg = "Error checking Windows Sandbox status: $($_.Exception.Message)"
		Write-Error $errorMsg
		
		[System.Windows.Forms.MessageBox]::Show(
			$errorMsg,
			"Error",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Error
		)
		
		return $false
	}
}
