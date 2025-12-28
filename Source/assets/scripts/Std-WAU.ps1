$SandboxFolderName = "DefaultFolder"
$InstallCmdPath = "$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd"

if (-not (Test-Path -Path $InstallCmdPath)) {
    throw "InstallWSB.cmd not found at: $InstallCmdPath"
}

Start-Process cmd.exe -ArgumentList "/c del /Q `"$env:USERPROFILE\Desktop\$SandboxFolderName\*.log`" & `"$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd`" && explorer `"$env:USERPROFILE\Desktop\$SandboxFolderName`""
