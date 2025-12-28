$SandboxFolderName = "DefaultFolder"
$sandboxPath = "$env:USERPROFILE\Desktop\$SandboxFolderName"

# Look for installer files (priority order)
# Opens Explorer if none found

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
	$extension = [System.IO.Path]::GetExtension($found).ToLower()
	$fullFilePath = Join-Path $sandboxPath $found
	
	switch ($extension) {
		{ $_ -in @('.cmd', '.bat') } {
			# CMD/BAT: Execute via cmd.exe with proper working directory
			Start-Process cmd.exe -ArgumentList "/c cd /d `"$sandboxPath`" && `"$found`""
		}
		default {
			# Default: Direct execution with working directory
			# Works for: .exe, .msi, etc.
			Start-Process $fullFilePath -WorkingDirectory $sandboxPath
		}
	}
} else {
	# No installer found, open Explorer
	Start-Process explorer.exe -ArgumentList "`"$sandboxPath`""
}