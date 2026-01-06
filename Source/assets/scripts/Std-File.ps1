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
		
		# Decode directly to output path using /out parameter
		Write-Host "Decoding $fullFilePath to $outputPath..."
		& $decoderPath $fullFilePath /s /out:$outputPath
		
		# Read Detection.xml from output path to get setup file name
		$detectionXmlPath = Join-Path $outputPath "Detection.xml"
		if (Test-Path $detectionXmlPath) {
			[xml]$xml = Get-Content $detectionXmlPath
			$setupFileName = $xml.ApplicationInfo.SetupFile
			Write-Host "Setup file from Detection.xml: $setupFileName"
			
			# Find and extract the decoded.zip file
			$decodedZip = Get-ChildItem -Path $outputPath -Filter "*.decoded.zip" | Select-Object -First 1
			if ($decodedZip) {
				$extractPath = Join-Path $outputPath "Extracted"
				Write-Host "Extracting $($decodedZip.Name) to $extractPath..."
				
				Add-Type -AssemblyName System.IO.Compression.FileSystem
				[System.IO.Compression.ZipFile]::ExtractToDirectory($decodedZip.FullName, $extractPath)
				
				# Run the setup file from extracted folder
				$setupFile = Join-Path $extractPath $setupFileName
				if (Test-Path $setupFile) {
					Write-Host "Running setup file: $setupFileName"
					Start-Process $setupFile -WorkingDirectory $extractPath
				} else {
					Write-Warning "Setup file not found: $setupFile"
				}
			} else {
				Write-Warning "No decoded.zip file found in output path: $outputPath"
			}
		} else {
			Write-Warning "Detection.xml not found in output path: $detectionXmlPath"
		}
	}
	default {
		# Default: Direct execution with working directory
		# Works for: .exe, .msi, .msix, .appx, .js, .py, .ahk, etc.
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
}


