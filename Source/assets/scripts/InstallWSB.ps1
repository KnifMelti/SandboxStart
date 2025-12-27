$SandboxFolderName = "DefaultFolder"
$InstallCmdPath = "$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd"

if (-not (Test-Path -Path $InstallCmdPath)) {
    Write-Error "InstallWSB.cmd not found at: $InstallCmdPath"
    exit 1
}

Start-Process cmd.exe -ArgumentList "/c del /Q `"$env:USERPROFILE\Desktop\$SandboxFolderName\*.log`" & `"$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd`" && explorer `"$env:USERPROFILE\Desktop\$SandboxFolderName`""
