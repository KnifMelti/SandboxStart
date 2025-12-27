$SandboxFolderName = "DefaultFolder"
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"

# Look for installer files (priority order)
# Opens Explorer if none found
# Note: Get-ChildItem -Filter is case-insensitive on Windows
# "Setup.exe" will match Setup.exe, setup.exe, SETUP.EXE, etc.
$installers = @(
	"Install.cmd",
	"Install.bat",
	"Setup.cmd",
	"Setup.bat",
	"Setup.exe",
	"Install.exe",
	"Installer.exe",
	"Setup.msi",
	"Install.msi",
	"Installer.msi"
)
$found = $null
foreach ($file in $installers) {
	$matchedFiles = Get-ChildItem -Path $sandboxPath -Filter $file -File -ErrorAction SilentlyContinue
	if ($matchedFiles) {
		$found = $matchedFiles[0].Name
		break
	}
}

if ($found) {
	if ($found -like "*.cmd" -or $found -like "*.bat") {
		Start-Process cmd.exe -ArgumentList "/c cd /d `"$sandboxPath`" && `"$found`""
	} elseif ($found -like "*.msi") {
		Start-Process msiexec.exe -ArgumentList "/i `"$sandboxPath\$found`""
	} else {
		Start-Process "$sandboxPath\$found" -WorkingDirectory $sandboxPath
	}
} else {
	Start-Process explorer.exe -ArgumentList "`"$sandboxPath`""
}
