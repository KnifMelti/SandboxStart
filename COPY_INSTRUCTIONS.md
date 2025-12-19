# File Copy Instructions for SandboxStart Project

## Manual Copy Required:

### SandboxTest.ps1
This file (~1800 lines) needs to be copied **unchanged** from:

**Source:**
```
WAU-Settings-GUI/Sources/WAU Settings GUI/SandboxTest.ps1
```

**Destination:**
```
SandboxStart/SandboxTest.ps1
```

**Action:** Copy the entire file without any modifications.

This file contains the core Windows Sandbox functionality and should work standalone without any WAU dependencies.

---

## Files Already Created:

✅ SandboxStart.ps1 (Main entry point)
✅ Test-WindowsSandbox.ps1 (WSB detection/installation)
⏳ Show-SandboxTestDialog.ps1 (Creating next...)
❌ SandboxTest.ps1 (Requires manual copy from source)

