<#
.SYNOPSIS
    Windows Sandbox Detection and Installation Helper

.DESCRIPTION
    Checks if Windows Sandbox is installed and enabled.
    Prompts user to enable the feature if not available.
    Handles pending reboot scenarios.
#>

# Load Windows Forms assembly for MessageBox
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

function Test-WindowsSandbox {
    <#
    .SYNOPSIS
    Checks Windows Sandbox availability and offers to enable if needed
    
    .DESCRIPTION
    Performs the following checks:
    1. Checks if WindowsSandbox.exe exists
    2. If missing, checks feature state
    3. If enabled but exe missing -> Prompt for reboot
    4. If disabled -> Offer to enable feature
    
    .OUTPUTS
    Boolean - True if Windows Sandbox is ready to use, False otherwise
    
    .EXAMPLE
    if (Test-WindowsSandbox) {
        # Proceed with sandbox operations
    }
    #>
    
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        $sandboxExe = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"
        
        if (Test-Path $sandboxExe) {
            # Windows Sandbox executable exists - ready to use
            Write-Verbose "Windows Sandbox is available at: $sandboxExe"
            return $true
        }
        
        # Executable missing - check feature state
        Write-Verbose "WindowsSandbox.exe not found, checking feature state..."
        $wsbFeature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -ErrorAction SilentlyContinue
        
        if ($wsbFeature -and $wsbFeature.State -eq 'Enabled') {
            # Feature enabled but exe missing -> Pending reboot
            Write-Warning "Windows Sandbox feature is enabled but executable is missing (restart required)"
            
            $message = "Windows Sandbox feature is enabled but the executable is missing:`n$sandboxExe`n`n"
            $message += "A restart is required before it can be used.`n`nRestart now?"
            
            $result = [System.Windows.MessageBox]::Show(
                $message,
                "Restart Required",
                [System.Windows.MessageBoxButton]::OKCancel,
                [System.Windows.MessageBoxImage]::Information
            )
            
            if ($result -eq [System.Windows.MessageBoxResult]::OK) {
                Write-Host "Restarting computer..." -ForegroundColor Yellow
                Restart-Computer -Force
            }
            
            return $false
        }
        else {
            # Feature not enabled - offer to enable it
            Write-Warning "Windows Sandbox is not enabled"
            
            $message = "Windows Sandbox is not enabled (executable missing:`n$sandboxExe).`n`n"
            $message += "Enable the feature now? (Restart required after enabling)"
            
            $result = [System.Windows.MessageBox]::Show(
                $message,
                "Windows Sandbox Not Enabled",
                [System.Windows.MessageBoxButton]::OKCancel,
                [System.Windows.MessageBoxImage]::Question
            )
            
            if ($result -ne [System.Windows.MessageBoxResult]::OK) {
                Write-Host "User cancelled Windows Sandbox installation." -ForegroundColor Yellow
                return $false
            }
            
            try {
                Write-Host "Enabling Windows Sandbox feature (this can take a while)..." -ForegroundColor Cyan
                
                Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart -ErrorAction Stop | Out-Null
                
                Write-Host "Windows Sandbox feature enabled successfully!" -ForegroundColor Green
                
                $message = "Feature enabled. A restart is required before Windows Sandbox can be used.`n`nRestart now?"
                
                $rebootResult = [System.Windows.MessageBox]::Show(
                    $message,
                    "Restart Required",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question
                )
                
                if ($rebootResult -eq [System.Windows.MessageBoxResult]::Yes) {
                    Write-Host "Restarting computer..." -ForegroundColor Yellow
                    Restart-Computer -Force
                }
                else {
                    Write-Host "Please restart your computer to complete Windows Sandbox installation." -ForegroundColor Yellow
                }
                
                return $false
            }
            catch {
                $errorMsg = "Failed to enable Windows Sandbox: $($_.Exception.Message)"
                Write-Error $errorMsg
                
                [System.Windows.MessageBox]::Show(
                    $errorMsg,
                    "Enable Failed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
                
                return $false
            }
        }
    }
    catch {
        $errorMsg = "Error checking Windows Sandbox status: $($_.Exception.Message)"
        Write-Error $errorMsg
        
        [System.Windows.MessageBox]::Show(
            $errorMsg,
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
        
        return $false
    }
}
