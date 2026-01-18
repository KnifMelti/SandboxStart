# To prevent GitHub sync from overwriting your changes, uncomment the line below:
# # CUSTOM

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SandboxFolderName,  # Relative path from Desktop (e.g., "SandboxTest\1.0.4.0" or "IntuneWinBuilder")

	[Parameter(Mandatory)]
	[string]$FileName
)

# Build full paths - Join-Path handles both simple and nested folder structures
$sandboxPath = Join-Path "$env:USERPROFILE\Desktop" $SandboxFolderName
$fullFilePath = Join-Path $sandboxPath $FileName

# Get file extension
$extension = [System.IO.Path]::GetExtension($FileName).ToLower()

# Build appropriate command based on file type
switch ($extension) {
	{ $_ -in @('.cmd', '.bat') } {
		# CMD/BAT: Execute via cmd.exe with proper working directory
		# Using cd /d ensures correct drive and directory, && ensures file only runs if cd succeeds
		Write-Host "Running: $FileName..."
		Start-Process cmd.exe -ArgumentList "/c cd /d `"$sandboxPath`" && `"$FileName`""
	}
	'.ps1' {
		# PS1: Execute via powershell.exe with working directory set
		Write-Host "Running: $FileName..."
		Start-Process powershell.exe -ArgumentList "-File `"$fullFilePath`"" -WorkingDirectory $sandboxPath
	}
	'.intunewin' {
		# IntuneWin: Extract using IntuneWinAppUtilDecoder
		$outputPath = Join-Path $env:TEMP "IntuneExtracted"
		
		New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
		
		# Download IntuneWinAppUtilDecoder.exe if not present
		$decoderPath = Join-Path $env:TEMP "IntuneWinAppUtilDecoder.exe"
		if (-not (Test-Path $decoderPath)) {
			Write-Host "Downloading IntuneWinAppUtilDecoder.exe..."
			$downloadUrl = "https://github.com/KnifMelti/SandboxStart/raw/master/Source/assets/IntuneWinAppUtilDecoder.exe"
			
			try {
				Invoke-WebRequest -Uri $downloadUrl -OutFile $decoderPath -UseBasicParsing -ErrorAction Stop
			} catch {
				Write-Warning "Failed to download IntuneWinAppUtilDecoder.exe: $_"
				Write-Warning "Internet connection required. Aborting .intunewin extraction."
				return
			}
		}
		
		# Decode to output path - creates Detection.xml and .decoded.zip
		Write-Host "Decoding $fullFilePath to $outputPath..."
		& $decoderPath $fullFilePath /s /out:$outputPath
		
		# Read Detection.xml to get setup file name
		$detectionXmlPath = Join-Path $outputPath "Detection.xml"
		if (-not (Test-Path $detectionXmlPath)) {
			Write-Warning "Detection.xml not found in output path: $detectionXmlPath"
			return
		}
		
		[xml]$xml = Get-Content $detectionXmlPath
		$setupFileName = $xml.ApplicationInfo.SetupFile
		Write-Host "Setup file from Detection.xml: $setupFileName"
		
		# Construct decoded.zip filename from original .intunewin filename
		$baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
		$decodedZipPath = Join-Path $outputPath "$baseName.decoded.zip"
		
		if (-not (Test-Path $decodedZipPath)) {
			Write-Warning "Decoded zip file not found: $decodedZipPath"
			return
		}
		
		# Extract decoded.zip directly to output path
		Write-Host "Extracting $baseName.decoded.zip..."
		Add-Type -AssemblyName System.IO.Compression.FileSystem
		[System.IO.Compression.ZipFile]::ExtractToDirectory($decodedZipPath, $outputPath)
		
		# Run the setup file
		$setupFile = Join-Path $outputPath $setupFileName
		if (Test-Path $setupFile) {
			Write-Host "Running setup file: $setupFileName"
			$setupExtension = [System.IO.Path]::GetExtension($setupFileName).ToLower()
			if ($setupExtension -eq '.ps1') {
				Start-Process powershell.exe -ArgumentList "-File `"$setupFile`"" -WorkingDirectory $outputPath
			} else {
				Start-Process $setupFile -WorkingDirectory $outputPath
			}
		} else {
			Write-Warning "Setup file not found: $setupFile"
		}
	}
	'.ahk' {
		# AHK: Download and extract AutoHotkey-Decompiler to Desktop\Decompiler
		$decompilerPath = Join-Path "$env:USERPROFILE\Desktop" "Decompiler"
		$zipPath = Join-Path $env:TEMP "Decompiler.zip"
		
		if (-not (Test-Path $decompilerPath)) {
			Write-Host "Downloading AutoHotkey-Decompiler from GitHub..."
			try {
				# Download zip directly from custom repository
				$downloadUrl = "https://github.com/KnifMelti/SandboxStart/raw/master/Source/assets/AutoHotkey-Decompiler.zip"
				Write-Host "Downloading from: $downloadUrl"
				Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
				
				# Extract to temp folder first (zip contains a root folder)
				$tempExtractPath = Join-Path $env:TEMP "Decompiler_Extract"
				if (Test-Path $tempExtractPath) {
					Remove-Item $tempExtractPath -Recurse -Force
				}
				New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null
				
				Write-Host "Extracting AutoHotkey-Decompiler..."
				Add-Type -AssemblyName System.IO.Compression.FileSystem
				[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtractPath)
				
				# Get the single subdirectory
				$rootFolder = Get-ChildItem -Path $tempExtractPath -Directory | Select-Object -First 1
				
				# Create Decompiler folder on Desktop
				Write-Host "Creating Decompiler folder on Desktop..."
				New-Item -ItemType Directory -Path $decompilerPath -Force | Out-Null
				
				# Move contents from root folder to Decompiler
				Write-Host "Moving files to Desktop\Decompiler..."
				Get-ChildItem -Path $rootFolder.FullName -Recurse | Move-Item -Destination $decompilerPath -Force
				
				# Clean up temp files
				Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
				Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
			} catch {
				Write-Warning "Failed to download/extract AutoHotkey-Decompiler: $_"
				Write-Warning "Continuing with script execution anyway..."
			}
		}
		
		# Register Decompiler.exe in registry for .exe file context menu
		$decompilerExePath = Join-Path $decompilerPath "_decompiler\Decompiler.exe"
		if (Test-Path $decompilerExePath) {
			$regKeyPath = "HKCU:\Software\Classes\exefile\shell\DecompileAHK"
			$regCommandPath = "$regKeyPath\command"
			
			try {
				# Create registry key structure
				if (-not (Test-Path $regKeyPath)) {
					New-Item -Path $regKeyPath -Force | Out-Null
				}
				
				# Set menu text
				Set-ItemProperty -Path $regKeyPath -Name "(Default)" -Value "Decompile AutoHotkey Script" -Type String
				
				# Set icon from Decompiler.exe
				Set-ItemProperty -Path $regKeyPath -Name "Icon" -Value "`"$decompilerExePath`"" -Type String
				
				# Create command subkey
				if (-not (Test-Path $regCommandPath)) {
					New-Item -Path $regCommandPath -Force | Out-Null
				}
				
				# Set command with %1 parameter
				Set-ItemProperty -Path $regCommandPath -Name "(Default)" -Value "`"$decompilerExePath`" `"%1`"" -Type String
				
				Write-Host "Registered Decompiler.exe in context menu for .exe files"
			} catch {
				Write-Warning "Failed to register Decompiler.exe in registry: $_"
			}
		}
		
		# Customize settings for AutoHotkey scripts
		# Set UTF8 registry key for .ahk files (for AutoHotkey v1)
		$regPath = "HKCU:\Software\AutoHotkey\Launcher\v1"
		if (-not (Test-Path $regPath)) {
			New-Item -Path $regPath -Force | Out-Null
		}
		Set-ItemProperty -Path $regPath -Name "UTF8" -Value 1 -Type String
		Write-Host "Set AutoHotkey UTF8 registry key"
		
		# Set default editor for AutoHotkey scripts
		$editCommandPath = "HKCU:\SOFTWARE\Classes\AutoHotkeyScript\shell\edit\command"
		if (-not (Test-Path $editCommandPath)) {
			New-Item -Path $editCommandPath -Force | Out-Null
		}
		Set-ItemProperty -Path $editCommandPath -Name "(Default)" -Value '"C:\Windows\system32\NOTEPAD.EXE" "%1"'
		Write-Host "Set AutoHotkey default editor to Notepad"
		
		# Create AutoHotkey template structure in Documents
		$templatePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "AutoHotkey\Templates"
		if (-not (Test-Path $templatePath)) {
			New-Item -ItemType Directory -Path $templatePath -Force | Out-Null
			Write-Host "Created AutoHotkey Templates folder"
		}
		
		# Create KnifMelti Std.ahk template file
		$templateFile = Join-Path $templatePath "KnifMelti Std.ahk"
		$templateContent = @"
/*
[NewScriptTemplate]
Description = KnifMelti Std.
*/
#Requires AutoHotkey v2.0
SetWorkingDir A_ScriptDir  ; Ensures a consistent starting directory.
SplitPath(A_ScriptName, , , , &name_no_ext)
FileEncoding "UTF-8"

; name_no_ext contains the Script name to use

"@
		Set-Content -Path $templateFile -Value $templateContent -Encoding UTF8 -Force
		Write-Host "Created KnifMelti Std.ahk template"
		
		# Execute the .ahk file
		Write-Host "Running: $FileName..."
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
	'.au3' {
		# AU3: Download and extract source code from latest GitHub release to Desktop\Decompiler, then execute
		$apiUrl = "https://api.github.com/repos/daovantrong/myAutToExe/releases/latest"
		$matePath = Join-Path "$env:USERPROFILE\Desktop" "Decompiler"
		$zipPath = Join-Path $env:TEMP "MATE.zip"
		
		# Download and extract source code if it doesn't exist
		if (-not (Test-Path $matePath)) {
			Write-Host "Fetching latest AutoIt-Decompiler release from GitHub..."
			try {
				# Get latest release information from GitHub API
				$release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
				$downloadUrl = $release.zipball_url
				
				Write-Host "Downloading AutoIt-Decompiler from: $downloadUrl"
				Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
				
				# Extract to temp folder first (GitHub zipballs contain a root folder)
				$tempExtractPath = Join-Path $env:TEMP "MATE_Extract"
				if (Test-Path $tempExtractPath) {
					Remove-Item $tempExtractPath -Recurse -Force
				}
				New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null
				
				Write-Host "Extracting AutoIt-Decompiler..."
				Add-Type -AssemblyName System.IO.Compression.FileSystem
				[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtractPath)
				
				# Get the single subdirectory (GitHub zipball root folder)
				$rootFolder = Get-ChildItem -Path $tempExtractPath -Directory | Select-Object -First 1
				
				# Create MATE folder on Desktop
				Write-Host "Creating Decompiler folder on Desktop..."
				New-Item -ItemType Directory -Path $matePath -Force | Out-Null
				
				# Move contents from root folder to MATE
				Write-Host "Moving files to Desktop\Decompiler..."
				Get-ChildItem -Path $rootFolder.FullName -Recurse | Move-Item -Destination $matePath -Force
				
				# Clean up temp files
				Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
				Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
			} catch {
				Write-Warning "Failed to download/extract AutoIt-Decompiler: $_"
				Write-Warning "Continuing with script execution anyway..."
			}
		}
		
		# Execute the .au3 file
		Write-Host "Running: $FileName..."
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
	default {
		# Default: Direct execution with working directory
		# Works for: .exe, .msi, .msix, .appx, .js, .py, etc.
		Write-Host "Running: $FileName..."
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
}




