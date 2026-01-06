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
		Start-Process cmd.exe -ArgumentList "/c cd /d `"$sandboxPath`" && `"$FileName`""
	}
	'.ps1' {
		# PS1: Execute via powershell.exe with working directory set
		Start-Process powershell.exe -ArgumentList "-File `"$fullFilePath`"" -WorkingDirectory $sandboxPath
	}
	'.intunewin' {
		# IntuneWin: Extract using IntuneWinAppUtilDecoder
		$outputPath = Join-Path $env:TEMP "IntuneExtracted"
		
		# Clean up previous extraction if it exists
		if (Test-Path $outputPath) {
			Remove-Item $outputPath -Recurse -Force -ErrorAction SilentlyContinue
		}
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
			Start-Process $setupFile -WorkingDirectory $outputPath
		} else {
			Write-Warning "Setup file not found: $setupFile"
		}
	}
	default {
		# Default: Direct execution with working directory
		# Works for: .exe, .msi, .msix, .appx, .js, .py, .ahk, etc.
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
}


