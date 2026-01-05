$SandboxFolderName = "DefaultFolder"

$command = "Set-Location C:\; " +
	"winget validate '$env:USERPROFILE\Desktop\$SandboxFolderName'; " +
	"Read-Host 'Press Enter to install local manifest'; " +
	"winget install --manifest '$env:USERPROFILE\Desktop\$SandboxFolderName' --accept-source-agreements --accept-package-agreements; " +
	"Read-Host 'Press Enter to exit'; " +
	"exit"

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $command
