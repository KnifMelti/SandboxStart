$Script:WorkingDir = $PSScriptRoot
# Import required assemblies
Add-Type -AssemblyName System.Drawing
. $WorkingDir\shared\SandboxTest.ps1

function Get-ScriptMappings {
	<#
	.SYNOPSIS
	Reads script mapping configuration from external file
	
	.DESCRIPTION
	Loads script-to-pattern mappings from wsb\script-mappings.txt.
	Format: Pattern = ScriptName.ps1
	Example: InstallWSB.cmd = InstallWSB.ps1
	#>
	
	$mappingFile = Join-Path $Script:WorkingDir "wsb\script-mappings.txt"
	$mappings = @()
	
	# Create default mapping file if it doesn't exist
	if (-not (Test-Path $mappingFile)) {
		$wsbDir = Split-Path $mappingFile -Parent
		if (-not (Test-Path $wsbDir)) {
			New-Item -ItemType Directory -Path $wsbDir -Force | Out-Null
		}
		
		$defaultContent = @"
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
		Set-Content -Path $mappingFile -Value $defaultContent -Encoding ASCII
	}
	
	# Read and parse mapping file
	try {
		$lines = Get-Content -Path $mappingFile -Encoding UTF8 -ErrorAction Stop
		
		foreach ($line in $lines) {
			$line = $line.Trim()
			
			# Skip comments and empty lines
			if ($line.StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) {
				continue
			}
			
			# Parse: Pattern = Script.ps1
			if ($line -match '^\s*(.+?)\s*=\s*(.+?)\s*$') {
				$pattern = $matches[1].Trim()
				$script = $matches[2].Trim()
				
				# Validate script name ends with .ps1
				if ($script -like "*.ps1") {
					$mappings += @{
						Pattern = $pattern
						Script = $script
					}
				}
			}
		}
	}
	catch {
		Write-Warning "Failed to read script mappings: $($_.Exception.Message)"
	}
	
	# Ensure fallback exists
	if (-not ($mappings | Where-Object { $_.Pattern -eq "*.*" })) {
		$mappings += @{
			Pattern = "*.*"
			Script = "Explorer.ps1"
		}
	}
	
	return $mappings
}

function Get-PackageLists {
	<#
	.SYNOPSIS
	Retrieves all package list files from wsb directory

	.DESCRIPTION
	Scans the wsb directory for .txt files (excluding script-mappings.txt)
	and returns their base names for use in the package list dropdown.

	.OUTPUTS
	Array of package list names (without .txt extension)
	#>

	$packageListDir = Join-Path $Script:WorkingDir "wsb"
	$lists = @()

	if (Test-Path $packageListDir) {
		$txtFiles = Get-ChildItem -Path $packageListDir -Filter "*.txt" -File -ErrorAction SilentlyContinue
		foreach ($file in $txtFiles) {
			# Exclude script-mappings.txt from package lists
			if ($file.Name -ne "script-mappings.txt") {
				$lists += $file.BaseName
			}
		}
	}

	return $lists | Sort-Object
}

function Get-PackageListTooltip {
	<#
	.SYNOPSIS
	Returns tooltip text based on whether package lists exist
	#>

	$lists = Get-PackageLists
	if ($lists.Count -eq 0) {
		return "No package lists found. Click '[Create new list...]' to create one."
	}
	return "Select a package list to install via WinGet"
}

function Show-PackageListEditor {
	<#
	.SYNOPSIS
	Shows dialog for creating or editing package lists

	.PARAMETER ListName
	Optional list name to edit. If empty, creates new list.

	.OUTPUTS
	Hashtable with DialogResult and ListName
	#>
	param(
		[string]$ListName = ""
	)

	# Create editor form
	$editorForm = New-Object System.Windows.Forms.Form
	$editorForm.Text = if ($ListName) { "Edit Package List: $ListName" } else { "Create New Package List" }
	$editorForm.Size = New-Object System.Drawing.Size(420, 370)
	$editorForm.StartPosition = "CenterParent"
	$editorForm.FormBorderStyle = "FixedDialog"
	$editorForm.MaximizeBox = $false
	$editorForm.MinimizeBox = $false

	# Use the same icon as main form
	try {
		if ($Script:AppIcon) {
			$editorForm.Icon = $Script:AppIcon
			$editorForm.ShowIcon = $true
		} else {
			$editorForm.ShowIcon = $false
		}
	}
	catch {
		$editorForm.ShowIcon = $false
	}

	$y = 15
	$margin = 15
	$controlWidth = 380

	# List name field
	$lblListName = New-Object System.Windows.Forms.Label
	$lblListName.Location = New-Object System.Drawing.Point($margin, $y)
	$lblListName.Size = New-Object System.Drawing.Size(150, 20)
	$lblListName.Text = "List Name:"
	$editorForm.Controls.Add($lblListName)

	$txtListName = New-Object System.Windows.Forms.TextBox
	$txtListName.Location = New-Object System.Drawing.Point($margin, ($y + 20))
	$txtListName.Size = New-Object System.Drawing.Size($controlWidth, 23)
	$txtListName.Text = $ListName
	$txtListName.ReadOnly = ($ListName -ne "")
	$editorForm.Controls.Add($txtListName)

	$y += 50

	# Package IDs text area
	$lblPackages = New-Object System.Windows.Forms.Label
	$lblPackages.Location = New-Object System.Drawing.Point($margin, $y)
	$lblPackages.Size = New-Object System.Drawing.Size(400, 20)
	$lblPackages.Text = "Package IDs (one per line):"
	$editorForm.Controls.Add($lblPackages)

	$txtPackages = New-Object System.Windows.Forms.TextBox
	$txtPackages.Location = New-Object System.Drawing.Point($margin, ($y + 25))
	$txtPackages.Size = New-Object System.Drawing.Size($controlWidth, 140)
	$txtPackages.Multiline = $true
	$txtPackages.ScrollBars = "Vertical"
	$txtPackages.AcceptsReturn = $true
	$txtPackages.Font = New-Object System.Drawing.Font("Consolas", 9)
	$editorForm.Controls.Add($txtPackages)

	# Load existing content if editing
	if ($ListName) {
		$listPath = Join-Path (Join-Path $Script:WorkingDir "wsb") "$ListName.txt"
		if (Test-Path $listPath) {
			try {
				$txtPackages.Text = (Get-Content -Path $listPath -Raw -Encoding UTF8).Trim()
			}
			catch {
				[System.Windows.Forms.MessageBox]::Show("Error loading list: $($_.Exception.Message)", "Load Error", "OK", "Error")
			}
		}
	}

	$y += 175

	# Help text
	$lblHelp = New-Object System.Windows.Forms.Label
	$lblHelp.Location = New-Object System.Drawing.Point($margin, $y)
	$lblHelp.Size = New-Object System.Drawing.Size($controlWidth, 50)
	$lblHelp.Text = "Example: Notepad++.Notepad++`nUse WinGet package IDs from winget search`nComments: Lines starting with # are ignored"
	$lblHelp.ForeColor = [System.Drawing.Color]::Gray
	$editorForm.Controls.Add($lblHelp)

	$y += 50

	# Buttons
	$btnSave = New-Object System.Windows.Forms.Button
	$btnSave.Location = New-Object System.Drawing.Point(($margin + $controlWidth - 160), $y)
	$btnSave.Size = New-Object System.Drawing.Size(75, 30)
	$btnSave.Text = "Save"
	$btnSave.Add_Click({
		$listNameValue = $txtListName.Text.Trim()

		# Validate list name
		if ([string]::IsNullOrWhiteSpace($listNameValue)) {
			[System.Windows.Forms.MessageBox]::Show("Please enter a list name.", "Validation Error", "OK", "Warning")
			return
		}

		# Check for invalid filename characters
		$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
		if ($listNameValue.IndexOfAny($invalidChars) -ge 0) {
			[System.Windows.Forms.MessageBox]::Show("List name contains invalid characters.", "Validation Error", "OK", "Warning")
			return
		}

		# Prevent overwriting script-mappings.txt
		if ($listNameValue -eq "script-mappings") {
			[System.Windows.Forms.MessageBox]::Show("Cannot use reserved name 'script-mappings'.", "Validation Error", "OK", "Warning")
			return
		}

		# Save the file
		$wsbDir = Join-Path $Script:WorkingDir "wsb"
		if (-not (Test-Path $wsbDir)) {
			New-Item -ItemType Directory -Path $wsbDir -Force | Out-Null
		}

		$listPath = Join-Path $wsbDir "$listNameValue.txt"
		try {
			$packageContent = $txtPackages.Text.Trim()
			Set-Content -Path $listPath -Value $packageContent -Encoding UTF8

			$script:__editorReturn = @{
				DialogResult = 'OK'
				ListName = $listNameValue
			}
			$editorForm.Close()
		}
		catch {
			[System.Windows.Forms.MessageBox]::Show("Error saving list: $($_.Exception.Message)", "Save Error", "OK", "Error")
		}
	})
	$editorForm.Controls.Add($btnSave)

	$btnCancel = New-Object System.Windows.Forms.Button
	$btnCancel.Location = New-Object System.Drawing.Point(($margin + $controlWidth - 75), $y)
	$btnCancel.Size = New-Object System.Drawing.Size(75, 30)
	$btnCancel.Text = "Cancel"
	$btnCancel.Add_Click({
		$script:__editorReturn = @{ DialogResult = 'Cancel' }
		$editorForm.Close()
	})
	$editorForm.Controls.Add($btnCancel)

	$editorForm.AcceptButton = $btnSave
	$editorForm.CancelButton = $btnCancel

	[void]$editorForm.ShowDialog()

	if ($script:__editorReturn) {
		return $script:__editorReturn
	} else {
		return @{ DialogResult = 'Cancel' }
	}
}

# Determine the appropriate script based on selected file or directory contents
function Find-MatchingScript {
	param(
		[string]$Path,
		[string]$FileName = $null
	)
	
	$mappings = Get-ScriptMappings
	
	# If specific file selected, test against patterns
	if ($FileName) {
		foreach ($mapping in $mappings) {
			if ($FileName -like $mapping.Pattern) {
				return $mapping.Script
			}
		}
	}
	
	# If no file or no match, scan directory for pattern matches
	if (Test-Path $Path) {
		# Exclude *.* fallback from directory scan
		$scanMappings = $mappings | Where-Object { $_.Pattern -ne "*.*" }
		
		foreach ($mapping in $scanMappings) {
			$matchingFiles = Get-ChildItem -Path $Path -Filter $mapping.Pattern -File -ErrorAction SilentlyContinue
			if ($matchingFiles) {
				return $mapping.Script
			}
		}
	}
	
	# Fallback to last mapping (should be *.*)
	$fallback = $mappings | Where-Object { $_.Pattern -eq "*.*" } | Select-Object -First 1
	if ($fallback) {
		return $fallback.Script
	} else {
		return "Explorer.ps1"
	}
}

# Helper function to fetch stable WinGet versions from GitHub
function Get-StableWinGetVersions {
	<#
	.SYNOPSIS
	Fetches the 25 most recent stable WinGet versions from GitHub
	
	.DESCRIPTION
	Queries the GitHub API for microsoft/winget-cli releases and returns
	the tag names of the 25 most recent stable (non-prerelease) versions
	that have assets available. Excludes releases without assets to prevent
	installation failures.
	
	.OUTPUTS
	Array of version strings (e.g., "v1.7.10514", "v1.7.10582")
	#>
	try {
		# Request 100 releases to ensure we get 25 stable ones after filtering pre-releases and checking assets
		# Assumption: Among the 100 most recent releases, at least 25 will be stable (non-prerelease) with assets
		# This is typically true for the winget-cli repository which has regular stable releases
		$releasesApiUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
		Write-Verbose "Fetching WinGet releases from GitHub API..."
		
		# Fetch releases from GitHub API with timeout and User-Agent header
		$releases = Invoke-RestMethod -Uri $releasesApiUrl -TimeoutSec 10 -UserAgent "WAU-Settings-GUI" -UseBasicParsing -ErrorAction Stop
		
		# Filter to only stable releases (not prerelease) that have assets and get top 25
		$stableReleases = $releases | Where-Object { 
			(-not $_.prerelease) -and 
			($_.assets) -and 
			($_.assets.Count -gt 0) 
		} | Select-Object -First 25
		
		# Extract tag names (e.g., "v1.7.10514")
		$versions = $stableReleases | ForEach-Object { $_.tag_name }
		
		Write-Verbose "Found $($versions.Count) stable WinGet versions with assets"
		return $versions
	}
	catch {
		Write-Warning "Failed to fetch WinGet versions from GitHub: $($_.Exception.Message)"
		return @()
	}
}

# Helper function to validate WinGet version exists
function Test-WinGetVersionExists {
	<#
	.SYNOPSIS
	Validates if a WinGet version exists in the GitHub repository
	
	.PARAMETER Version
	The version string to validate (e.g., "1.23", "v1.7.10514")
	
	.PARAMETER IncludePrerelease
	Include prerelease versions in the search
	
	.OUTPUTS
	Boolean indicating if the version exists
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$Version,
		
		[Parameter(Mandatory = $false)]
		[bool]$IncludePrerelease = $false
	)
	
	try {
		$releasesApiUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
		Write-Verbose "Validating WinGet version: $Version"

		$releases = Invoke-RestMethod -Uri $releasesApiUrl -TimeoutSec 10 -UserAgent "WAU-Settings-GUI" -UseBasicParsing -ErrorAction Stop
		
		if (-not $IncludePrerelease) {
			$releases = $releases | Where-Object { -not $_.prerelease }
		}
		
		# Check if version matches any tag_name (with or without 'v' prefix)
		$versionPattern = '^v?' + [regex]::Escape($Version)
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

# Define the dialog function here since it's needed before the main functions section
function Show-SandboxTestDialog {
	<#
	.SYNOPSIS
	Shows a GUI dialog for configuring Windows Sandbox test parameters

	.DESCRIPTION
	Creates a Windows Forms dialog to collect all parameters needed for SandboxTest function
	#>

	# Embedded icon data (Base64-encoded from Source\assets\icon.ico)
	# Generated: 2025-12-20
	# Original size: 15KB (.ico) → 20KB (base64)
	$iconBase64 = @"
AAABAAMAMDAAAAEAIACoJQAANgAAACAgAAABACAAqBAAAN4lAAAQEAAAAQAgAGgEAACGNgAAKAAAADAAAABgAAAAAQAgAAAAAACAJQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/78/BP+/PwQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/MMw/+yzNP/sgun/7EKp3+wCVK/rAnDQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD+2jYO/tE6T/7RN7P+zTPy/8gt///CKP//viLw/rserv63G0v+sBMNAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/to2Dv7ROk/+0jiz/tM58f/ROP//zjP//8gt///CJ///vSH//7kd//+3G/D+uBqu/rYbSv6wEw0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP7aNg7+0TpP/tI6s/7TOvH/0jn//9I4///RN///zTL//8cs///BJv//vCD//7gc//+3G//+thr+/7UZ8P60GK/+thhK/rATDQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD+2jYO/tE6T/7UOrP+0zrx/9M6///SOf//0jj//9I4///RN///zTL//8cs///BJv//vCD//7gb//+2Gv//thn//7UY//+0F///sxfw/rMVr/6zFEr+sBMNAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/to2Dv7ROk/+1Dqz/tQ68f/TOv//0zn//9I5///SOP//0jj//9I4///RN///zTP//8gt///CJ///vSH//7gc//+2Gv//tRn//7QY//+0F///sxb//rIV/v+xFPD+sRSu/rMRSv6wEw0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/MMw/+1TpP/tQ6s/7TO/L+0zr+/9M5///TOf//0zn//9I5///SOf//0jj//9I5///SOP//zjP//8gt///DKP//vSL//7kd//+3G///thn//7UY//+zF///shX//7EU//+wE///sBL//68S8P6uEa/+rxFK/rATDQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD+2jYO/tU6T/7UO7P+0zvy/9M7///TOv//0zr//9M5///TOf//0zn//9I5///TOf//0zn//9M5///SOP//zjT//8ku///EKf//vyP//7oe//+4HP//txr//7UZ//+0F///shX//7EU//+wE///rxL//64R//6tEP7/rQ/w/qwOrv6sDUr+sBMNAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/to2Dv7VPU/+1Duz/tM78v/UO///0zr//9M6///TOv//0zr//9M6///TOf//0zr//9M6///TOv//0zr//9Q6///TOv//0DX//8sw///GK///wSX//7wg//+6Hv//uBz//7Ya//+1GP//sxb//7IU//+wE///rxL//64Q//+tD///rA7//6sO//+rDfD+qg2v/qwNSv6cEw0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/MRA/+1T1P/tU7s/7UPPL/1Dz//9Q7///TOv//0zr//9M6///TOv//0zr//9M6///UOv//0zr//9Q6///UO///1Dv//9U7///UO///0Tf//8wy///ILf//wyj//74j//+8If//uh7//7gc//+2Gv//tBj//7MW//+xE///rxL//64R//+tD///rA7//6sN//+qDP//qQv//6gK8P6nCq/+qApK/rATDQAAAAAAAAAAAAAAAAAAAAD+2kgO/tU9T/7VPbP+1Dzy/9Q8///UO///1Dv//9Q7///UO///0zr//9M6///TOv//0zv//9Q6///UO///1Dv//9Q7//7VPP/+1Tz//tU8///VPP//0jn//840//7KL//+xSr//8Em//6/JP//vCH//7of//+4HP//thr//7QX//+yFf//sBP//64R//+tD///rA7//6sN//+qC///qQr//6gJ//+nCf//pwjw/qcIr/6mCkv+sBMNAAAAAP/XP0D+1z6z/tU+8v/VPf//1Tz//9Q7///UO///1Dv//9Q7///UOv//1Dv//9Q7//7UO//+1Dv//tQ7///UPP/+1Tz//9U8//7WPf/+1j3//tY+///WPv//0zr//c41//7KMf/+xy3//sMp///BJv//vyT//70i//+6H//+uBz//rYa//+0F///shX//7AT//+uEf//rQ///6sN//+qDP//qAr//6cJ//+nCP//pgj//6cI//+oCfD+qQuu/qwMPv7XQNv/1j7//9Y+///VPf//1Dz//9Q7///UO///1Dv//9Q7///UO///1Dv//9Q7///UPP/+1Tz//9U8//7WPf//1j3//9Y+//7WPv/+1z///tc///vSPP/uuyv/3Z8Y/92dF//vsyL//MIp///EKf//wif//sAl//69Iv//uyD//rkd//+2Gv//tBj//rIV//+wEv//rhH//6wO//+qDP//qQr//6gJ//+nCP//pgf//6YI//+nCf/+qQv+/qsO2v/YQP//1z///9Y9///VPf//1Tz//9Q7///UO///1Dz//9U8///VPP//1Tz//9U8///VPf//1j3//tY+//7XPv//1z7//9c////YP//80z3/774v/9qcGP/Ohgn/zIUM/8uNIP/PixX/25gU/++xIP/7wCj//sIn//7AJf//viP//7wg//65Hf//txv//rUY//+yFf//sBP//64Q//+sDv//qgz//6gK//+nCP//pgf//6YH//+nCf//qQv//qwO/v/YQP//1z///9Y+///VPf//1T3//9U8///VPP//1Tz//9U9///VPf//1j3//9Y+///WPv//1z7//9c////YP///2ED//NQ+/+/JSP/Jwnj/vqtn/86NHP/QiA//vqhj/3+9wP+KuK3/taZo/8+IDf/blxL/77Af//y/Jv//wCb//74j//68If//uh7//7gb//+1Gf//sxb//7AT//+uEf//rA7//6oM//+oCv//pwj//6cI//+oCf//qQv//6wO///YQP//1z///9Y+///VPf//1T3//9U8///VPf//1j3//9Y+///XPv//1z7//9c///7XP///2ED//9hA//zUPf/wvzD/3Ko2/5rIuP9dxN//WbzY/4i2rv+btZ7/dMbV/02+3/9Lutv/c7e+/8uSKv/Ogwb/z4YI/9yWEf/wrx7//L4l//6/JP//vSH//7sf//+4HP//thr//7MX//+xE///rhH//6wO//+qDP//qQr//6gJ//+pCv//qgz//6wP///YQP//1z///9Y+///WPv//1j7//9Y9///WPv//1z7//9c+///XP///2D///9hA//7YQP/81D7/8cEx/9+hHf/UjQ//wapi/2fT6f9Tz+z/Sr/h/0m32/9Lv+D/V9z1/1jd9v9Rzur/TbXT/5q0nP/FoE3/w5xG/8mWM//RiQ3/3JgT//CwHv/8vCP//r0i//+7IP//uR3//7ca//+0F///sRT//68R//+sD///qw3//6oM//+qDP//qw3//60Q///YQP//2D///9c////XP///1z7//9c////XP///2D///9hA///YQP//2UH//dU+//HDM//hpSH/15IT/9WOEf/Wkx3/r8Wb/1/n/P9b5v3/V973/1XW8f9Y4Pf/WOj+/1jo/v9V4vv/RL3e/0m11f9ct8//WrjR/3m7wP/IoUv/0YkM/9ONDv/emxX/8bAe//y7Iv//vCD//7oe//+3G///tRj//7IV//+wEv//rhD//60P//+s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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJxOEw2hVgpKnlIJnptQCJ+ZTgZOkUgADgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAvz8ABL8/AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///////wAA////////AAD///////8AAP///////wAA///+f///AAD///gf//8AAP//4Af//wAA//+AAf//AAD//gAAf/8AAP/4AAAf/wAA/+AAAAf/AAD/gAAAAf8AAP4AAAAAfwAA+AAAAAAfAADgAAAAAAcAAIAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAEAAOAAAAAABwAA+AAAAAAfAAD+AAAAAH8AAP+AAAAB/wAA/+AAAAf/AAD/+AAAH/8AAP/+AAB//wAA//+AAf//AAD//+AH//8AAP//+B///wAA///+f///AAD///////8AAP///////wAA////////AAD///////8AACgAAAAgAAAAQAAAAAEAIAAAAAAAgBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7RNhz/yS9g/sMoX/68JRv//wABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7RNhz+0zlv/tA2z/7ILvr+wSX5/7sfzP64HGz+sxwb//8AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7aPxz+0zlv/tM4zv7SOfr/0Db//8ku///AJf//uR3//rca+f+2Gsz+tRds/rMSG///AAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7aPxz+0zlv/tI5z/7TOfr/0jn//9I4///QNv//yC7//8Ak//+5Hf//thr//7UZ//60F/n/shbM/rEVbP6zEhv//wABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7aPxz+1Ttv/tM5z/7TOvr/0zn//9I5///SOP//0jj//9E3///JL///wSb//7oe//+3Gv//tRj//7MW//+yFf/+sRP5/7ASzP6uEGz+qRIb//8AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAf7aPxz+1Ttv/tM7z/7TO/r/0zr//9M5///TOf//0zn//9M5///TOf//0Tj//8sx///DKP//vCD//7gc//+2Gf//tBf//7IU//+wE///rxH//q4P+f+sD8z+rA5s/qkJG///AAEAAAAAAAAAAAAAAAAAAAAA//8AAf7aPxz+1Ttv/tM8z/7UO/r/1Dr//9M6///TOv//0zr//9M6///TOv//1Dr//9Q7///TOf//zTP//8Yr//+/I///ux///7gc//+1Gf//sxb//7AT//+uEf//rQ///6sN//6rDPn/qgvM/qcJbP6pCRv//wABAAAAAP7ZQhv+1T5v/tU8z/7UPPr/1Dv//9Q7///UOv//1Dv//9Q7///UO///1Dv//9Q8///VPP//1T3//9U8///PNv//yS///sIo//+/JP//vCD//7gc//+1Gf//shX//68S//+tD///qw3//6kL//+oCf/+pwj5/6cIzP6nCWz+rQoZ/tc+w/7WPvr/1T3//9Q7///UO///1Dv//9Q7///UO///1Dz//9U8//7VPf/+1j3//tY+//7XPv/5zTf/67Ml/+uvIf/5vif//sIo///AJP//vCH//7kd//+1Gf//shX//68S//+sD///qgz//6gJ//+mCP//pgj//qgK+f6rDcH+1z/+/9Y+///VPf//1Dz//9Q8///VPP//1Tz//9U9///WPf//1j7//9c+//7XP//50kL/5r0//9aUFP/LjBz/uptJ/82cMf/oqR3/+bwl//7AJf//vSL//7ke//+2Gf//sxb//68S//+sDv//qQv//6cI//+mCP//qAn//qsN/v/XP///1j7//9U9///VPP//1T3//9Y9///WPv//1z7//9c///7XP//5zzr/6Lw8/6TFoP94u7z/oKh8/5K4ov9bwNn/erSw/8qPI//Wjw3/6aca//m6Iv/+vSL//7of//+3G///sxb//7AS//+sDv//qQv//6gJ//+pCv//qw7//9hA///XP///1j7//9Y+///WPv//1z///9g////YQP/60Dv/7Lgr/9uZGP/Ap1X/Zdjr/1DM6v9Pw+L/Vtnz/1bd9v9Pv9v/i7Cc/6amcv+8nUv/2JMT/+qoGv/6uSH//rsg//+4HP//tBf//7AT//+tD///qw3//6sN//+tD///2UH//9hA///XP///1z///9hA//7YQP/3zjv/7bov/9+hHv/ZlBX/xaVQ/43G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
"@

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

		# Load embedded icon
		try {
			$iconBytes = [System.Convert]::FromBase64String($iconBase64)
			$memoryStream = New-Object System.IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
			$script:AppIcon = New-Object System.Drawing.Icon($memoryStream)
			$appIcon = $script:AppIcon
		}
		catch {
			Write-Warning "Failed to load embedded icon: $($_.Exception.Message)"
			$script:AppIcon = $null
			$appIcon = $null
		}

		# Create the main form
		$form = New-Object System.Windows.Forms.Form
		$form.Text = "Windows Sandbox Test Configuration"
		$form.Size = New-Object System.Drawing.Size(450, 725)
		$form.StartPosition = "CenterScreen"
		$form.FormBorderStyle = "FixedDialog"
		$form.MaximizeBox = $false
		$form.MinimizeBox = $false

		# Set custom icon if available
		if ($appIcon) {
			$form.Icon = $appIcon
			$form.ShowIcon = $true
		}
		else {
			$form.ShowIcon = $false
		}

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

		# Install Packages section
		$lblInstallPackages = New-Object System.Windows.Forms.Label
		$lblInstallPackages.Location = New-Object System.Drawing.Point($leftMargin, $y)
		$lblInstallPackages.Size = New-Object System.Drawing.Size(200, $labelHeight)
		$lblInstallPackages.Text = "Install Packages:"
		$form.Controls.Add($lblInstallPackages)

		$cmbInstallPackages = New-Object System.Windows.Forms.ComboBox
		$cmbInstallPackages.Location = New-Object System.Drawing.Point($leftMargin, ($y + $labelHeight))
		$cmbInstallPackages.Size = New-Object System.Drawing.Size(($controlWidth - 85), $controlHeight)
		$cmbInstallPackages.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

		$tooltipPackages = New-Object System.Windows.Forms.ToolTip
		$tooltipPackages.SetToolTip($cmbInstallPackages, (Get-PackageListTooltip))

		# Populate dropdown
		$packageLists = Get-PackageLists
		[void]$cmbInstallPackages.Items.Add("")

		if ($packageLists.Count -eq 0) {
			$cmbInstallPackages.Items.Add("[Create new list...]")
			$cmbInstallPackages.SelectedIndex = 0
		} else {
			foreach ($list in $packageLists) {
				[void]$cmbInstallPackages.Items.Add($list)
			}
			[void]$cmbInstallPackages.Items.Add("[Create new list...]")
			$cmbInstallPackages.SelectedIndex = 0
		}

		# Selection change event
		$cmbInstallPackages.Add_SelectedIndexChanged({
			if ($this.SelectedItem -eq "[Create new list...]") {
				$result = Show-PackageListEditor

				if ($result.DialogResult -eq 'OK') {
					$currentSelection = $result.ListName
					$this.Items.Clear()
					[void]$this.Items.Add("")

					$lists = Get-PackageLists
					foreach ($list in $lists) {
						[void]$this.Items.Add($list)
					}
					[void]$this.Items.Add("[Create new list...]")

					$this.SelectedItem = $currentSelection
					$tooltipPackages.SetToolTip($this, (Get-PackageListTooltip))
				} else {
					$this.SelectedIndex = 0
				}
			}
		})

		$form.Controls.Add($cmbInstallPackages)

		# Edit button
		$btnEditPackages = New-Object System.Windows.Forms.Button
		$btnEditPackages.Location = New-Object System.Drawing.Point(($leftMargin + $controlWidth - 75), ($y + $labelHeight))
		$btnEditPackages.Size = New-Object System.Drawing.Size(75, $controlHeight)
		$btnEditPackages.Text = "Edit..."
		$btnEditPackages.Add_Click({
			$selectedList = $cmbInstallPackages.SelectedItem

			if ($selectedList -eq "" -or $selectedList -eq "[Create new list...]") {
				[System.Windows.Forms.MessageBox]::Show("Please select a package list to edit.", "No Selection", "OK", "Information")
				return
			}

			$result = Show-PackageListEditor -ListName $selectedList

			if ($result.DialogResult -eq 'OK') {
				$currentSelection = $selectedList
				$cmbInstallPackages.Items.Clear()
				[void]$cmbInstallPackages.Items.Add("")

				$lists = Get-PackageLists
				foreach ($list in $lists) {
					[void]$cmbInstallPackages.Items.Add($list)
				}
				[void]$cmbInstallPackages.Items.Add("[Create new list...]")

				$cmbInstallPackages.SelectedItem = $currentSelection
			}
		})
		$form.Controls.Add($btnEditPackages)

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
				InstallPackageList = if ($cmbInstallPackages.SelectedItem -and
				                       $cmbInstallPackages.SelectedItem -ne "" -and
				                       $cmbInstallPackages.SelectedItem -ne "[Create new list...]") {
				                       $cmbInstallPackages.SelectedItem
				                   } else { "" }
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
		if ($appIcon) { $appIcon.Dispose() }
		if ($memoryStream) { $memoryStream.Dispose() }
	}
}
