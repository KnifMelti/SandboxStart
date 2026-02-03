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
		# AHK: Download and extract AHK-Hacker to Desktop\AHK-Hacker
		$apiUrl = "https://api.github.com/repos/KnifMelti/AHK-Hacker/releases/latest"
		$ahkHackerPath = Join-Path "$env:USERPROFILE\Desktop" "AHK-Hacker"
		$zipPath = Join-Path $env:TEMP "AHK-Hacker.zip"
		
		if (-not (Test-Path $ahkHackerPath)) {
			# Run the download/prompt in a separate PowerShell window and continue this script
			$childScriptContent = @'
param(
    [string]$apiUrl,
    [string]$ahkHackerPath,
    [string]$zipPath
)

try {
    # Prompt user to download decompiler with 10-second timeout
    Write-Host "`nDo you want to download the AHK-Hacker decompiler?" -ForegroundColor Yellow
    Write-Host "Press ENTER to download, ESC to skip (auto-skip in 10 seconds)..." -ForegroundColor Cyan
    
    $shouldDownload = $false
    $timeout = 10
    $startTime = Get-Date
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') {
                $shouldDownload = $true
                break
            } elseif ($key.Key -eq 'Escape') {
                Write-Host "Skipping AHK-Hacker download.`n" -ForegroundColor Gray
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
    
    if (-not $shouldDownload) {
        if (((Get-Date) - $startTime).TotalSeconds -ge $timeout) {
            Write-Host "Timeout reached. Skipping AHK-Hacker download.`n" -ForegroundColor Gray
        }
    } else {
        Write-Host "Fetching latest AHK-Hacker release from GitHub..."
        try {
            # Get latest release information from GitHub API
            $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
            
            # Find the AHK-Hacker-*.zip asset
            $asset = $release.assets | Where-Object { $_.name -like "AHK-Hacker-*.zip" } | Select-Object -First 1
            if (-not $asset) {
                throw "No AHK-Hacker-*.zip file found in latest release"
            }
            
            $downloadUrl = $asset.browser_download_url
            Write-Host "Downloading AHK-Hacker from: $downloadUrl"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            
            # Extract zip to temp folder
            $tempExtractPath = Join-Path $env:TEMP "AHK-Hacker_Extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item $tempExtractPath -Recurse -Force
            }

            Write-Host "Extracting AHK-Hacker..."
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtractPath)

            # Move AHK-Hacker folder directly to Desktop
            Write-Host "Moving AHK-Hacker to Desktop..."
            $extractedFolder = Join-Path $tempExtractPath "AHK-Hacker"
            Move-Item -Path $extractedFolder -Destination $ahkHackerPath -Force

            # Clean up temp files
            Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            
			# Run AHK-Hacker.exe to register everything
			$exePath = Join-Path $ahkHackerPath "AHK-Hacker.exe"
			if (Test-Path $exePath) {
				Write-Host "Running AHK-Hacker.exe /install /silent..."
				Start-Process -FilePath $exePath -ArgumentList '/install /silent' -WorkingDirectory $ahkHackerPath -Wait
				Write-Host "AHK-Hacker installation completed"
			} else {
				Write-Warning "AHK-Hacker.exe not found in AHK-Hacker folder"
			}
        } catch {
            Write-Warning "Failed to download/extract AHK-Hacker: $_"
            Write-Warning "Continuing with script execution anyway..."
        }
    }
} catch {
    Write-Warning "Unhandled error: $_"
}
'@

			$tempChildPath = Join-Path $env:TEMP "AHK-Hacker-Download.ps1"
			Set-Content -Path $tempChildPath -Value $childScriptContent -Encoding UTF8

			Start-Process powershell.exe -ArgumentList @(
				'-NoLogo',
				'-NoProfile',
				'-ExecutionPolicy', 'Bypass',
				'-File', $tempChildPath,
				'-apiUrl', $apiUrl,
				'-ahkHackerPath', $ahkHackerPath,
				'-zipPath', $zipPath
			) -WindowStyle Normal
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
		# AU3: Download and extract mATE from GitHub to Desktop\mATE, then execute
		$downloadUrl = "https://github.com/KnifMelti/AHK-Hacker/raw/main/src/res/mATE.zip"
		$matePath = Join-Path "$env:USERPROFILE\Desktop" "mATE"
		$zipPath = Join-Path $env:TEMP "mATE.zip"
		
		# Download and extract mATE if it doesn't exist
		if (-not (Test-Path $matePath)) {
			# Run the download/prompt in a separate PowerShell window and continue this script
			$childScriptContent = @'
param(
    [string]$downloadUrl,
    [string]$matePath,
    [string]$zipPath
)

try {
    # Prompt user to download decompiler with 10-second timeout
    Write-Host "`nDo you want to download the AutoIt decompiler?" -ForegroundColor Yellow
    Write-Host "Press ENTER to download, ESC to skip (auto-skip in 10 seconds)..." -ForegroundColor Cyan
    
    $shouldDownload = $false
    $timeout = 10
    $startTime = Get-Date
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') {
                $shouldDownload = $true
                break
            } elseif ($key.Key -eq 'Escape') {
                Write-Host "Skipping AutoIt-Decompiler download.`n" -ForegroundColor Gray
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
    
    if (-not $shouldDownload) {
        if (((Get-Date) - $startTime).TotalSeconds -ge $timeout) {
            Write-Host "Timeout reached. Skipping AutoIt-Decompiler download.`n" -ForegroundColor Gray
        }
    } else {
        Write-Host "Downloading AutoIt-Decompiler from GitHub..."
        try {
            Write-Host "Downloading mATE from: $downloadUrl"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            
            # Extract to temp folder first
            $tempExtractPath = Join-Path $env:TEMP "mATE_Extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item $tempExtractPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null
            
            Write-Host "Extracting mATE..."
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtractPath)
            
            # Get the mATE subdirectory from the zip
            $mateFolder = Join-Path $tempExtractPath "mATE"
            
            if (Test-Path $mateFolder) {
                # Move mATE folder to Desktop
                Write-Host "Moving mATE folder to Desktop..."
                Move-Item -Path $mateFolder -Destination $matePath -Force
            } else {
                Write-Warning "mATE folder not found in extracted archive"
            }
            
            # Clean up temp files
            Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to download/extract AutoIt-Decompiler: $_"
            Write-Warning "Continuing with script execution anyway..."
        }
    }
} catch {
    Write-Warning "Unhandled error: $_"
}
'@

			$tempChildPath = Join-Path $env:TEMP "AutoIt-Decompiler-Download.ps1"
			Set-Content -Path $tempChildPath -Value $childScriptContent -Encoding UTF8

			Start-Process powershell.exe -ArgumentList @(
				'-NoLogo',
				'-NoProfile',
				'-ExecutionPolicy', 'Bypass',
				'-File', $tempChildPath,
				'-downloadUrl', $downloadUrl,
				'-matePath', $matePath,
				'-zipPath', $zipPath
			) -WindowStyle Normal
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




