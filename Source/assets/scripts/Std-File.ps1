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
	default {
		# Default: Direct execution with working directory
		# Works for: .exe, .msi, .js, .py, .ahk, etc.
		Start-Process $fullFilePath -WorkingDirectory $sandboxPath
	}
}
