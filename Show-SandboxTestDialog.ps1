Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-SandboxTestDialog {
	<#
	.SYNOPSIS
	Shows a GUI dialog for configuring Windows Sandbox test parameters

	.DESCRIPTION
	Creates a Windows Forms dialog to collect all parameters needed for SandboxTest function
	#>

	try {
		# Define default scripts array (no -f formatting; inject folder via regex replace)
		$defaultScripts = @{
			"InstallWSB" = @'
$SandboxFolderName = "DefaultFolder"
Start-Process cmd.exe -ArgumentList "/c del /Q `"$env:USERPROFILE\Desktop\$SandboxFolderName\*.log`" & `"$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd`" && explorer `"$env:USERPROFILE\Desktop\$SandboxFolderName`""
'@
			"WinGetManifest" = @'
$SandboxFolderName = "DefaultFolder"
Start-Process cmd.exe -ArgumentList "/k cd /d `"$env:USERPROFILE\Desktop\$SandboxFolderName`" && winget install --manifest . --accept-source-agreements --accept-package-agreements"
'@
			"Installer" = @'
$SandboxFolderName = "DefaultFolder"
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"

# Look for installer files (priority order)
$installers = @(
"Install.cmd","install.cmd","INSTALL.CMD",
"Install.bat","install.bat","INSTALL.BAT",
"Setup.exe","setup.exe","SETUP.EXE",
"Install.exe","install.exe","INSTALL.EXE",
"Installer.exe","installer.exe","INSTALLER.EXE"
)
$found = $null
foreach ($file in $installers) {
$path = Join-Path $sandboxPath $file
if (Test-Path $path) { $found = $file; break }
}

if ($found) {
if ($found -like "*.cmd" -or $found -like "*.bat") {
	Start-Process cmd.exe -ArgumentList "/c cd /d `"$sandboxPath`" && `"$found`""
} else {
	Start-Process "$sandboxPath\$found" -WorkingDirectory $sandboxPath
}
} else {
Start-Process explorer.exe -ArgumentList "`"$sandboxPath`""
}
'@
			"Explorer" = @'
$SandboxFolderName = "DefaultFolder"
Start-Process explorer.exe -ArgumentList "`"$env:USERPROFILE\Desktop\$SandboxFolderName`""
'@
		}

		# Ensure wsb directory exists (+ script-mappings.txt) and create default scripts if needed
		$wsbDir = Join-Path $WorkingDir "wsb"
		if (-not (Test-Path $wsbDir) -or -not (Test-Path (Join-Path $wsbDir "script-mappings.txt"))) {
			New-Item -ItemType Directory -Path $wsbDir -Force | Out-Null

			# Create default script files (write as-is; no -f formatting)
			foreach ($scriptName in $defaultScripts.Keys) {
				$scriptPath = Join-Path $wsbDir "$scriptName.ps1"
				$defaultScripts[$scriptName] | Out-File -FilePath $scriptPath -Encoding ASCII
			}
		}

		# Create script-mappings.txt if it doesn't exist (do this early)
		$mappingFile = Join-Path $wsbDir "script-mappings.txt"
		if (-not (Test-Path $mappingFile)) {
			$defaultMappingContent = @"
# Script Mapping Configuration for Windows Sandbox Testing
# Format: FilePattern = ScriptToExecute.ps1
#
# Patterns are evaluated in order. First match wins.
# Wildcards: * (any characters), ? (single character)
# The *.* pattern at the end acts as fallback.

InstallWSB.cmd = InstallWSB.ps1
*.installer.yaml = WinGetManifest.ps1
Install.* = Installer.ps1
*.* = Explorer.ps1
"@
			Set-Content -Path $mappingFile -Value $defaultMappingContent -Encoding ASCII
		}

		# Create the main form
		$form = New-Object System.Windows.Forms.Form
		$form.Text = "Windows Sandbox Test Configuration"
		$form.Size = New-Object System.Drawing.Size(450, 665)
		$form.StartPosition = "CenterScreen"
		$form.FormBorderStyle = "FixedDialog"
		$form.MaximizeBox = $false
		$form.MinimizeBox = $false
		$form.ShowIcon = $false

		# Create controls
		$y = 20
		$labelHeight = 20
		$controlHeight = 23
		$spacing = 10
		$leftMargin = 20
		$controlWidth = 400

		# Mapped Folder selection
		$lblMapFolder = New-Object System.Windows.Forms.Label
		$lblMapFolder.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblMapFolder.Size = New-Object System.Drawing.Size(150, $labelHeight)
		$lblMapFolder.Text = "Mapped Folder:"
		$form.Controls.Add($lblMapFolder)

		$txtMapFolder = New-Object System.Windows.Forms.TextBox
		$txtMapFolder.Location = New-Object System.Drawing.Point($leftMargin, ($y + $labelHeight))
		$txtMapFolder.Size = New-Object System.Drawing.Size($controlWidth, $controlHeight)
		# Set default path based on whether msi directory exists and find latest version
		$msiDir = Join-Path $WorkingDir "msi"
		if (Test-Path $msiDir) {
			# Look for version directories (e.g., 2.6.1, 2.7.0) and get the latest one
			$versionDirs = Get-ChildItem -Path $msiDir -Directory | Where-Object { 
				$_.Name -match '^\d+\.\d+\.\d+$' 
			} | Sort-Object { [Version]$_.Name } -Descending
			
			if ($versionDirs) {
				$txtMapFolder.Text = $versionDirs[0].FullName
			} else {
				$txtMapFolder.Text = $msiDir
			}
		} else {
			$txtMapFolder.Text = $WorkingDir
		}
		$form.Controls.Add($txtMapFolder)

		$y += $labelHeight + $controlHeight + 5

		# Folder browse button
		$btnBrowse = New-Object System.Windows.Forms.Button
		$btnBrowse.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$btnBrowse.Size = New-Object System.Drawing.Size(($controlWidth / 2 - 5), $controlHeight)
		$btnBrowse.Text = "Folder..."
		$btnBrowse.Add_Click({
			$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
			$folderDialog.Description = "Select folder to map in Windows Sandbox"
			$folderDialog.SelectedPath = $txtMapFolder.Text
			$folderDialog.ShowNewFolderButton = $false
			
			if ($folderDialog.ShowDialog() -eq "OK") {
				$selectedDir = $folderDialog.SelectedPath
				
				# Folder selected - use directory logic
				$txtMapFolder.Text = $selectedDir
				
				# Update sandbox folder name
				$msiFiles = Get-ChildItem -Path $selectedDir -Filter "WAU*.msi" -File -ErrorAction SilentlyContinue
				if ($msiFiles) {
					$txtSandboxFolderName.Text = "WAU-install"
				} else {
					$folderName = Split-Path $selectedDir -Leaf
					# Check if it's a root drive (contains : or is a path like D:\)
					if (![string]::IsNullOrWhiteSpace($folderName) -and $folderName -notmatch ':' -and $folderName -ne '\') {
						$txtSandboxFolderName.Text = $folderName
					} else {
						# Root drive selected (e.g., D:\) - use drive letter as folder name
						$driveLetter = $selectedDir.TrimEnd('\').Replace(':', '')
						if (![string]::IsNullOrWhiteSpace($driveLetter)) {
							$txtSandboxFolderName.Text = "Drive_$driveLetter"
						} else {
							$txtSandboxFolderName.Text = "MappedFolder"
						}
					}
				}
				
				# Find matching script from mappings
				$matchingScript = Find-MatchingScript -Path $selectedDir
				$scriptName = $matchingScript.Replace('.ps1', '')
				
				# Try to get script content from multiple sources
				$scriptContent = $null
				
				# 1. Check if the script exists in $defaultScripts (hardcoded)
				if ($defaultScripts.ContainsKey($scriptName)) {
					$scriptContent = $defaultScripts[$scriptName]
					# Inject chosen folder name
					$scriptContent = $scriptContent -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`""
				}
				# 2. Check if the .ps1 file exists in wsb\ directory
				elseif (Test-Path (Join-Path $wsbDir $matchingScript)) {
					$scriptFilePath = Join-Path $wsbDir $matchingScript
					try {
						$scriptContent = Get-Content -Path $scriptFilePath -Raw -Encoding UTF8
						# Replace placeholder with actual folder name
						$scriptContent = $scriptContent -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`""
					}
					catch {
						Write-Warning "Failed to load script from $scriptFilePath`: $($_.Exception.Message)"
						$scriptContent = $null
					}
				}
				
				# 3. Fallback to Explorer if script not found anywhere
				if ([string]::IsNullOrWhiteSpace($scriptContent)) {
					$scriptContent = $defaultScripts["Explorer"]
					$scriptContent = $scriptContent -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`""
					$lblStatus.Text = "Status: Mapping fallback to Explorer.ps1"
				} else {
					$lblStatus.Text = "Status: Mapping -> $matchingScript"
				}
				
				$txtScript.Text = $scriptContent
			}
		})
		$form.Controls.Add($btnBrowse)
		
		# File browse button
		$btnBrowseFile = New-Object System.Windows.Forms.Button
		$btnBrowseFile.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth / 2 + 5), $y)
		$btnBrowseFile.Size = New-Object System.Drawing.Size(($controlWidth / 2 - 5), $controlHeight)
		$btnBrowseFile.Text = "File..."
		$btnBrowseFile.Add_Click({
			$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
			$fileDialog.Title = "Select file to run in Windows Sandbox"
			$fileDialog.Filter = "Executable Files (*.exe;*.cmd;*.bat;*.ps1)|*.exe;*.cmd;*.bat;*.ps1|All Files (*.*)|*.*"
			$fileDialog.InitialDirectory = $txtMapFolder.Text
			
			if ($fileDialog.ShowDialog() -eq "OK") {
				$selectedPath = $fileDialog.FileName
				$selectedDir = [System.IO.Path]::GetDirectoryName($selectedPath)
				$selectedFile = [System.IO.Path]::GetFileName($selectedPath)
				
				# File selected - use its directory
				$txtMapFolder.Text = $selectedDir
				
				# Update sandbox folder name based on directory only (no WAU detection)
				$folderName = Split-Path $selectedDir -Leaf
				# Check if it's a root drive (contains : or is a path like D:\)
				if (![string]::IsNullOrWhiteSpace($folderName) -and $folderName -notmatch ':' -and $folderName -ne '\') {
					$txtSandboxFolderName.Text = $folderName
				} else {
					# Root drive selected (e.g., D:\) - use drive letter as folder name
					$driveLetter = $selectedDir.TrimEnd('\').Replace(':', '')
					if (![string]::IsNullOrWhiteSpace($driveLetter)) {
						$txtSandboxFolderName.Text = "Drive_$driveLetter"
					} else {
						$txtSandboxFolderName.Text = "MappedFolder"
					}
				}
				
				# Generate script for selected file directly (no folder content detection)
				$extension = [System.IO.Path]::GetExtension($selectedFile).ToLower()
				
				# Build appropriate command based on file type
				if ($extension -eq '.exe') {
					# EXE: Direct execution from sandbox folder
					$txtScript.Text = @"
`$SandboxFolderName = "$($txtSandboxFolderName.Text)"
Start-Process "`$env:USERPROFILE\Desktop\`$SandboxFolderName\$selectedFile" -WorkingDirectory "`$env:USERPROFILE\Desktop\`$SandboxFolderName"
"@
				}
				elseif ($extension -in @('.cmd', '.bat')) {
					# CMD/BAT: Execute via cmd.exe /c with proper working directory
					$txtScript.Text = @"
`$SandboxFolderName = "$($txtSandboxFolderName.Text)"
Start-Process cmd.exe -ArgumentList "/c cd /d ```"`$env:USERPROFILE\Desktop\`$SandboxFolderName```" && ```"$selectedFile```""
"@
				}
				elseif ($extension -eq '.ps1') {
					# PS1: Execute via powershell.exe with full path
					$txtScript.Text = @"
`$SandboxFolderName = "$($txtSandboxFolderName.Text)"
Start-Process powershell.exe -ArgumentList "-File ```"`$env:USERPROFILE\Desktop\`$SandboxFolderName\$selectedFile```""
"@
				}
				else {
					# Default: Try to run directly using Start-Process with file association
					$txtScript.Text = @"
`$SandboxFolderName = "$($txtSandboxFolderName.Text)"
Start-Process "`$env:USERPROFILE\Desktop\`$SandboxFolderName\$selectedFile" -WorkingDirectory "`$env:USERPROFILE\Desktop\`$SandboxFolderName"
"@
				}

				$lblStatus.Text = "Status: File selected -> $selectedFile ($extension)"
			}
		})
		$form.Controls.Add($btnBrowseFile)

		$y += $labelHeight + $controlHeight + $spacing

		# Sandbox Folder Name
		$lblSandboxFolderName = New-Object System.Windows.Forms.Label
		$lblSandboxFolderName.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblSandboxFolderName.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$lblSandboxFolderName.Text = "Sandbox Desktop Folder Name:"
		$form.Controls.Add($lblSandboxFolderName)

		$txtSandboxFolderName = New-Object System.Windows.Forms.TextBox
		$txtSandboxFolderName.Location = New-Object System.Drawing.Point($leftMargin, ($y + $labelHeight))
		$txtSandboxFolderName.Size = New-Object System.Drawing.Size($controlWidth, $controlHeight)
		# Set default based on whether WAU MSI exists in the mapped folder
		$msiFiles = Get-ChildItem -Path $txtMapFolder.Text -Filter "WAU*.msi" -File -ErrorAction SilentlyContinue
		if ($msiFiles) {
			$txtSandboxFolderName.Text = "WAU-install"
		} else {
			$initialFolderName = Split-Path $txtMapFolder.Text -Leaf
			# Check if it's a root drive (contains : or is a path like D:\)
			if (![string]::IsNullOrWhiteSpace($initialFolderName) -and $initialFolderName -notmatch ':' -and $initialFolderName -ne '\') {
				$txtSandboxFolderName.Text = $initialFolderName
			} else {
				# Root drive - extract drive letter
				$driveLetter = $txtMapFolder.Text.TrimEnd('\').Replace(':', '')
				if (![string]::IsNullOrWhiteSpace($driveLetter)) {
					$txtSandboxFolderName.Text = "Drive_$driveLetter"
				} else {
					$txtSandboxFolderName.Text = "MappedFolder"
				}
			}
		}

		# Add event handler to update script when folder name changes
		$txtSandboxFolderName.Add_TextChanged({
			$currentScript = $txtScript.Text
			if (![string]::IsNullOrWhiteSpace($currentScript)) {
				# Replace the SandboxFolderName variable value in the existing script
				$txtScript.Text = $currentScript -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`""
			}
		})

		$form.Controls.Add($txtSandboxFolderName)

		$y += $labelHeight + $controlHeight + $spacing

		# WinGet Version - using ComboBox with fetched versions
		$lblWinGetVersion = New-Object System.Windows.Forms.Label
		$lblWinGetVersion.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblWinGetVersion.Size = New-Object System.Drawing.Size(300, $labelHeight)
		$lblWinGetVersion.Text = "WinGet Version (leave empty for latest):"
		$form.Controls.Add($lblWinGetVersion)

		$cmbWinGetVersion = New-Object System.Windows.Forms.ComboBox
		$cmbWinGetVersion.Location = New-Object System.Drawing.Point($leftMargin, ($y + $labelHeight))
		$cmbWinGetVersion.Size = New-Object System.Drawing.Size($controlWidth, $controlHeight)
		$cmbWinGetVersion.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
		
		# Add empty option first (for "latest") - only item initially
		[void]$cmbWinGetVersion.Items.Add("")
		$cmbWinGetVersion.SelectedIndex = 0
		
		# Lazy load versions only when user opens the dropdown
		# This avoids unnecessary API calls when users just want the latest version
		# Use Tag property to track if versions have been loaded (avoids script-scope issues)
		$cmbWinGetVersion.Tag = $false
		
		$cmbWinGetVersion.Add_DropDown({
			# Use $this to reference the ComboBox safely within the event handler
			if (-not $this.Tag) {
				# Show loading indicator
				$originalText = $this.Text
				$this.Text = "Loading versions..."
				[System.Windows.Forms.Application]::DoEvents()  # Force UI update
				
				try {
					Write-Verbose "Fetching stable WinGet versions for dropdown..."
					$stableVersions = Get-StableWinGetVersions
					
					# Add fetched versions to the dropdown
					foreach ($version in $stableVersions) {
						[void]$this.Items.Add($version)
					}
					
					Write-Verbose "WinGet version dropdown populated with $($stableVersions.Count) stable versions"
				}
				catch {
					Write-Warning "Failed to populate WinGet versions dropdown: $($_.Exception.Message)"
				}
				finally {
					# Always restore original text and mark as loaded, even if API call failed
					# Restore to original text (typically empty string on first open)
					$this.Text = $originalText
					$this.Tag = $true
				}
			}
		})
		
		$form.Controls.Add($cmbWinGetVersion)

		$y += $labelHeight + $controlHeight + $spacing + 10

		# Checkboxes
		$chkPrerelease = New-Object System.Windows.Forms.CheckBox
		$chkPrerelease.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$chkPrerelease.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$chkPrerelease.Text = "Pre-release (of WinGet)"
		$form.Controls.Add($chkPrerelease)
		
		# Add event handler after both controls are added to form
		# Store reference to combo box in checkbox's Tag for safe access
		$chkPrerelease.Tag = $cmbWinGetVersion
		$chkPrerelease.Add_CheckedChanged({
			$comboBox = $this.Tag
			if ($this.Checked) {
				# Disable version field when Pre-release is checked
				$comboBox.Enabled = $false
				$comboBox.Text = ""
			} else {
				# Enable version field when Pre-release is unchecked
				$comboBox.Enabled = $true
			}
		})

		$y += $labelHeight + 5

		$chkClean = New-Object System.Windows.Forms.CheckBox
		$chkClean.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$chkClean.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$chkClean.Text = "Clean (cached dependencies)"
		$form.Controls.Add($chkClean)

		$y += $labelHeight + 5

		$chkAsync = New-Object System.Windows.Forms.CheckBox
		$chkAsync.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$chkAsync.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$chkAsync.Text = "Async (return directly)"
		$chkAsync.Checked = $true
		$form.Controls.Add($chkAsync)

		$y += $labelHeight + 5

		$chkVerbose = New-Object System.Windows.Forms.CheckBox
		$chkVerbose.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$chkVerbose.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$chkVerbose.Text = "Verbose (screen log)"
		$form.Controls.Add($chkVerbose)

		$y += $labelHeight + 5

		$chkWait = New-Object System.Windows.Forms.CheckBox
		$chkWait.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$chkWait.Size = New-Object System.Drawing.Size(250, $labelHeight)
		$chkWait.Text = "Wait (before exit PS window)"
		$form.Controls.Add($chkWait)

		$y += $labelHeight + $spacing + 10

		# (Removed) force CMD execution option; PowerShell execution is robust enough

		$y += $labelHeight + 5

		# Script section
		$lblScript = New-Object System.Windows.Forms.Label
		$lblScript.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblScript.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$lblScript.Text = "Script:"
		$form.Controls.Add($lblScript)

		# Load/Save buttons for scripts
		$btnLoadScript = New-Object System.Windows.Forms.Button
		$btnLoadScript.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth - 160), $y)
		$btnLoadScript.Size = New-Object System.Drawing.Size(75, $controlHeight)
		$btnLoadScript.Text = "Load"
		$btnLoadScript.Add_Click({
			$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
			$openFileDialog.InitialDirectory = $wsbDir
			$openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
			$openFileDialog.Title = "Load Script"

			if ($openFileDialog.ShowDialog() -eq "OK") {
				try {
					$scriptContent = Get-Content -Path $openFileDialog.FileName -Raw -Encoding UTF8
					$txtScript.Text = $scriptContent

					# Extract SandboxFolderName from the loaded script
					$pattern = '\$SandboxFolderName\s*=\s*"([^"]*)"'
					if ($scriptContent -match $pattern) {
						$extractedFolderName = $matches[1]
						if (![string]::IsNullOrWhiteSpace($extractedFolderName) -and $extractedFolderName -ne "DefaultFolder") {
							$txtSandboxFolderName.Text = $extractedFolderName
						}
					}

					# Update script content with current folder name from the text field
					$currentFolderName = $txtSandboxFolderName.Text
					if (![string]::IsNullOrWhiteSpace($currentFolderName)) {
						$txtScript.Text = $txtScript.Text -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$currentFolderName`""
					}
				}
				catch {
					[System.Windows.Forms.MessageBox]::Show("Error loading script: $($_.Exception.Message)", "Load Error", "OK", "Error")
				}
			}
		})
		$form.Controls.Add($btnLoadScript)

		$btnSaveScript = New-Object System.Windows.Forms.Button
		$btnSaveScript.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth - 75), $y)
		$btnSaveScript.Size = New-Object System.Drawing.Size(75, $controlHeight)
		$btnSaveScript.Text = "Save"
		$btnSaveScript.Add_Click({
			if ([string]::IsNullOrWhiteSpace($txtScript.Text)) {
				[System.Windows.Forms.MessageBox]::Show("No script content to save.", "Save Error", "OK", "Warning")
				return
			}

			$saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
			$saveFileDialog.InitialDirectory = $wsbDir
			$saveFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
			$saveFileDialog.DefaultExt = "ps1"
			$saveFileDialog.Title = "Save Script"

			if ($saveFileDialog.ShowDialog() -eq "OK") {
				# Enforce .ps1 extension even if user removes it in filename box
				$targetPath = if ([System.IO.Path]::GetExtension($saveFileDialog.FileName).ToLower() -ne ".ps1") { "$($saveFileDialog.FileName).ps1" } else { $saveFileDialog.FileName }
				
				# Check if trying to overwrite a predefined script
				$targetFileName = [System.IO.Path]::GetFileName($targetPath)
				$protectedFiles = @("InstallWSB.ps1", "WinGetManifest.ps1", "Explorer.ps1")
				if ($protectedFiles -contains $targetFileName) {
					[System.Windows.Forms.MessageBox]::Show("Cannot overwrite predefined script '$targetFileName'. Please choose a different filename.", "Save Error", "OK", "Warning")
					return
				}
				
				try {
					# Ensure wsb directory exists
					if (-not (Test-Path $wsbDir)) {
						New-Item -ItemType Directory -Path $wsbDir -Force | Out-Null
					}
					$txtScript.Text | Out-File -FilePath $targetPath -Encoding ASCII
					[System.Windows.Forms.MessageBox]::Show("Script saved successfully!", "Save Complete", "OK", "Information")
				}
				catch {
					[System.Windows.Forms.MessageBox]::Show("Error saving script: $($_.Exception.Message)", "Save Error", "OK", "Error")
				}
			}
		})
		$form.Controls.Add($btnSaveScript)

		$txtScript = New-Object System.Windows.Forms.TextBox
		$txtScript.Location = New-Object System.Drawing.Point($leftMargin, ($y + $labelHeight + 5))
		$txtScript.Size = New-Object System.Drawing.Size($controlWidth, 120)
		$txtScript.Multiline = $true
		$txtScript.ScrollBars = "Vertical"
		# Set default script based on folder contents
		$installWSBPath = Join-Path $txtMapFolder.Text "InstallWSB.cmd"
		$installerYamlFiles = Get-ChildItem -Path $txtMapFolder.Text -Filter "*.installer.yaml" -File -ErrorAction SilentlyContinue
		# Use mapping on initial folder to detect Installer.ps1 scenario
		$matchingScriptInit = Find-MatchingScript -Path $txtMapFolder.Text

		if (Test-Path $installWSBPath) {
			$txtScript.Text = ($defaultScripts["InstallWSB"] -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`"")
			$initialStatus = "Auto default: InstallWSB.ps1 (InstallWSB.cmd found)"
		} elseif ($installerYamlFiles) {
			$txtScript.Text = ($defaultScripts["WinGetManifest"] -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`"")
			$initialStatus = "Auto default: WinGetManifest.ps1 (*.installer.yaml found)"
		} elseif ($matchingScriptInit -eq 'Installer.ps1') {
			$txtScript.Text = ($defaultScripts["Installer"] -replace '\$SandboxFolderName\s*=\s*"[^\"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`"")
			$initialStatus = "Auto default: Installer.ps1 (mapping matched)"
		} else {
			$txtScript.Text = ($defaultScripts["Explorer"] -replace '\$SandboxFolderName\s*=\s*"[^"]*"', "`$SandboxFolderName = `"$($txtSandboxFolderName.Text)`"")
			$initialStatus = "Auto default: Explorer.ps1"
		}
		$form.Controls.Add($txtScript)

		# Status label (mapping/result info)
		$y += $labelHeight + 5 + 120 + 5
		$lblStatus = New-Object System.Windows.Forms.Label
		$lblStatus.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblStatus.Size = New-Object System.Drawing.Size($controlWidth, $labelHeight)
		$lblStatus.Text = "Status: $initialStatus"
		$form.Controls.Add($lblStatus)

		$y += $labelHeight + $spacing + 10

		# Buttons
		$btnOK = New-Object System.Windows.Forms.Button
		$btnOK.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth - 160), $y)
		$btnOK.Size = New-Object System.Drawing.Size(75, 30)
		$btnOK.Text = "OK"
		$btnOK.Add_Click({
			$resultScript = $null
			if (-not [string]::IsNullOrWhiteSpace($txtScript.Text)) {
				try { $resultScript = [ScriptBlock]::Create($txtScript.Text) } catch { $resultScript = $null }
			}

			$script:__dialogReturn = @{
				DialogResult = 'OK'
				MapFolder = $txtMapFolder.Text
				SandboxFolderName = $txtSandboxFolderName.Text
				WinGetVersion = $cmbWinGetVersion.Text
				Prerelease = $chkPrerelease.Checked
				Clean = $chkClean.Checked
				Async = $chkAsync.Checked
				Verbose = $chkVerbose.Checked
				Wait = $chkWait.Checked
				Script = $resultScript
			}
			$form.Close()
		})
		$form.Controls.Add($btnOK)

		$btnCancel = New-Object System.Windows.Forms.Button
		$btnCancel.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth - 75), $y)
		$btnCancel.Size = New-Object System.Drawing.Size(75, 30)
		$btnCancel.Text = "Cancel"
		$btnCancel.Add_Click({
			$script:__dialogReturn = @{ DialogResult = 'Cancel' }
			$form.Close()
		})
		$form.Controls.Add($btnCancel)

		# Set default accept/cancel buttons
		$form.AcceptButton = $btnOK
		$form.CancelButton = $btnCancel

		# Show dialog (modal)
		[void]$form.ShowDialog()

		# Prepare return object
		if ($script:__dialogReturn) {
			return $script:__dialogReturn
		} else {
			return @{ DialogResult = 'Cancel' }
		}
	}
	catch {
		[System.Windows.Forms.MessageBox]::Show("Error creating dialog: $($_.Exception.Message)", "Error", "OK", "Error")
		return @{ DialogResult = "Cancel" }
	}
	finally {
		if ($form) { $form.Dispose() }
	}
}
