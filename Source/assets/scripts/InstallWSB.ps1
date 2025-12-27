$SandboxFolderName = "DefaultFolder"
Start-Process cmd.exe -ArgumentList "/c del /Q `"$env:USERPROFILE\Desktop\$SandboxFolderName\*.log`" & `"$env:USERPROFILE\Desktop\$SandboxFolderName\InstallWSB.cmd`" && explorer `"$env:USERPROFILE\Desktop\$SandboxFolderName`""
