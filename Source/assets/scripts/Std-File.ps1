# Std-File.ps1 - Execute files in Windows Sandbox
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SandboxFolderName,

	[Parameter(Mandatory)]
	[string]$FileName
)

# Build full paths
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"
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
		$extractPath = Join-Path $env:TEMP "IntuneExtracted_$([guid]::NewGuid().ToString())"
		New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
		
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
		
		# Read Detection.xml to get setup file name
		Add-Type -AssemblyName System.IO.Compression.FileSystem
		$zipArchive = [System.IO.Compression.ZipFile]::OpenRead($fullFilePath)
		$detectionEntry = $zipArchive.Entries | Where-Object { $_.FullName -eq "IntuneWinPackage/Metadata/Detection.xml" }
		
		$setupFileName = $null
		if ($detectionEntry) {
			$stream = $detectionEntry.Open()
			$reader = New-Object System.IO.StreamReader($stream)
			[xml]$xml = $reader.ReadToEnd()
			$setupFileName = $xml.ApplicationInfo.SetupFile
			Write-Host "Setup file from XML: $setupFileName"
			$reader.Close()
			$stream.Close()
		}
		$zipArchive.Dispose()
		
		# Copy .intunewin file to temp folder for decoding
		$tempIntuneFile = Join-Path $extractPath ([System.IO.Path]::GetFileName($fullFilePath))
		Copy-Item $fullFilePath $tempIntuneFile -Force
		
		# Decode using IntuneWinAppUtilDecoder
		$decodedZip = $tempIntuneFile -replace '\.intunewin$', '.decoded.zip'
		Write-Host "Decoding $tempIntuneFile..."
		& $decoderPath $tempIntuneFile /s /filePath:$decodedZip
		
		# Extract the decoded.zip file
		$decryptedPath = Join-Path $extractPath "Decrypted"
		
		if (Test-Path $decodedZip) {
			Write-Host "Extracting $decodedZip to $decryptedPath"
			[System.IO.Compression.ZipFile]::ExtractToDirectory($decodedZip, $decryptedPath)
			
			# Run the setup file
			$setupFile = Join-Path $decryptedPath $setupFileName
			if (Test-Path $setupFile) {
				Write-Host "Running setup file: $setupFileName"
				Start-Process $setupFile -WorkingDirectory $decryptedPath
			} else {
				Write-Warning "Setup file not found: $setupFile"
			}
		} else {
			Write-Warning "Decoded ZIP not found: $decodedZip"
		}
	}
	default {
		# Default: Direct execution with working directory
		# Works for: .exe, .msi, .msix, .appx, .js, .py, .ahk, etc.
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
}
