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
	# For .py files: Requires Python installed via WinGet package list (with file association)
	if ($extension -eq '.py') {
		$pythonExe = Get-Command python.exe -ErrorAction SilentlyContinue
		if (-not $pythonExe) {
			# Python not found - show error message
			Write-Host ""
			Write-Host "================================================" -ForegroundColor Red
			Write-Host "ERROR: Python Not Found" -ForegroundColor Red
			Write-Host "================================================" -ForegroundColor Red
			Write-Host ""
			Write-Host "Python is required to execute .py files but was not found." -ForegroundColor Yellow
			Write-Host ""
			Write-Host "Possible reasons:" -ForegroundColor Cyan
			Write-Host "  1. Networking was disabled - Python cannot be installed via WinGet" -ForegroundColor White
			Write-Host "  2. Python package list was not selected" -ForegroundColor White
			Write-Host "  3. Python installation failed during sandbox startup" -ForegroundColor White
			Write-Host ""
			Write-Host "To fix this:" -ForegroundColor Cyan
			Write-Host "  - Enable networking in SandboxStart dialog" -ForegroundColor White
			Write-Host "  - Select the 'Python' package list (or create Python.txt with Python.Python.3.13)" -ForegroundColor White
			Write-Host "  - Restart the sandbox" -ForegroundColor White
			Write-Host ""
			Write-Host "Press any key to open the folder instead..." -ForegroundColor Yellow
			$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

			# Fallback: Open Explorer
			Start-Process explorer.exe -ArgumentList "`"$env:USERPROFILE\Desktop\$SandboxFolderName`""
			return
		}
	}

	# For .ahk files: Requires AutoHotkey installed via WinGet package list (with file association)
	if ($extension -eq '.ahk') {
		$ahkExe = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue
		if (-not $ahkExe) {
			# AutoHotkey not found - show error message
			Write-Host ""
			Write-Host "================================================" -ForegroundColor Red
			Write-Host "ERROR: AutoHotkey Not Found" -ForegroundColor Red
			Write-Host "================================================" -ForegroundColor Red
			Write-Host ""
			Write-Host "AutoHotkey is required to execute .ahk files but was not found." -ForegroundColor Yellow
			Write-Host ""
			Write-Host "Possible reasons:" -ForegroundColor Cyan
			Write-Host "  1. Networking was disabled - AutoHotkey cannot be installed via WinGet" -ForegroundColor White
			Write-Host "  2. AHK package list was not selected" -ForegroundColor White
			Write-Host "  3. AutoHotkey installation failed during sandbox startup" -ForegroundColor White
			Write-Host ""
			Write-Host "To fix this:" -ForegroundColor Cyan
			Write-Host "  - Enable networking in SandboxStart dialog" -ForegroundColor White
			Write-Host "  - Select the 'AHK' package list (or create AHK.txt with AutoHotkey.AutoHotkey)" -ForegroundColor White
			Write-Host "  - Restart the sandbox" -ForegroundColor White
			Write-Host ""
			Write-Host "Press any key to open the folder instead..." -ForegroundColor Yellow
			$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

			# Fallback: Open Explorer
			Start-Process explorer.exe -ArgumentList "`"$env:USERPROFILE\Desktop\$SandboxFolderName`""
			return
		}
	}

	Start-Process "$env:USERPROFILE\Desktop\$SandboxFolderName\$FileName" -WorkingDirectory "$env:USERPROFILE\Desktop\$SandboxFolderName"
}
