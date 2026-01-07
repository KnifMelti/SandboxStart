$filePath = "e:\WinGet\SandboxStart\Source\shared\Shared-Helpers.ps1"
$lines = Get-Content -Path $filePath

# Find the problematic foreach line
for ($i = 0; $i -lt $lines.Count; $i++) {
	if ($lines[$i] -match 'foreach \(\$key in \(\$regularKeys \+ \$specialKeys\)\)') {
		Write-Host "Found problematic foreach at line $($i+1)" -ForegroundColor Cyan

		# Replace lines 1458-1463 with fixed version
		# Line i-3: # Sort entries...
		# Line i-2: $specialKeys = ...
		# Line i-1: $regularKeys = ...
		# Line i: (empty)
		# Line i+1: foreach ...
		# Line i+2: $lines += ...
		# Line i+3: }

		$newCode = @(
			"`t`t# Sort entries (but keep special entries at bottom)",
			"`t`t# Force arrays to prevent issues when there's only one key",
			"`t`t`$specialKeys = @(`$config.Keys | Where-Object { `$_ -like '_*' })",
			"`t`t`$regularKeys = @(`$config.Keys | Where-Object { `$_ -notlike '_*' } | Sort-Object)",
			"",
			"`t`t# Add regular keys first",
			"`t`tforeach (`$key in `$regularKeys) {",
			"`t`t`t`$lines += `"`$key=`$(`$config[`$key])`"",
			"`t`t}",
			"",
			"`t`t# Add special keys last",
			"`t`tforeach (`$key in `$specialKeys) {",
			"`t`t`t`$lines += `"`$key=`$(`$config[`$key])`"",
			"`t`t}"
		)

		# Replace from line i-3 to i+3 (7 lines) with new code (14 lines)
		$startLine = $i - 3
		$endLine = $i + 3

		$lines = $lines[0..($startLine - 1)] + $newCode + $lines[($endLine + 1)..($lines.Count - 1)]

		break
	}
}

# Save
$lines | Set-Content -Path $filePath -Encoding UTF8

Write-Host "Fixed array concatenation in Set-PackageListConfig!" -ForegroundColor Green
