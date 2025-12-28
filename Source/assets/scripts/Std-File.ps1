param(
	[Parameter(Mandatory)]
	[string]$SandboxFolderName,

	[Parameter(Mandatory)]
	[string]$FileName
)

$extension = [System.IO.Path]::GetExtension($FileName).ToLower()

# Build appropriate command based on file type
if ($extension -eq '.exe') {
	# EXE: Direct execution from sandbox folder
	Start-Process "$env:USERPROFILE\Desktop\$SandboxFolderName\$FileName" -WorkingDirectory "$env:USERPROFILE\Desktop\$SandboxFolderName"
}
elseif ($extension -in @('.cmd', '.bat')) {
	# CMD/BAT: Execute via cmd.exe /c with proper working directory
	Start-Process cmd.exe -ArgumentList "/c cd /d `"$env:USERPROFILE\Desktop\$SandboxFolderName`" && `"$FileName`""
}
elseif ($extension -eq '.ps1') {
	# PS1: Execute via powershell.exe with full path
	Start-Process powershell.exe -ArgumentList "-File `"$env:USERPROFILE\Desktop\$SandboxFolderName\$FileName`""
}
else {
	# Default: Try to run directly using Start-Process with file association (*.js, *.msi, *.py, *.ahk, etc.)
	Start-Process "$env:USERPROFILE\Desktop\$SandboxFolderName\$FileName" -WorkingDirectory "$env:USERPROFILE\Desktop\$SandboxFolderName"
}
