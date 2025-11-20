function Get-LocalSoftwareInventory {
    <#
    .SYNOPSIS
        Internal helper function that retrieves installed software from the local machine's registry.

    .DESCRIPTION
        This function queries the Uninstall registry keys (both 64-bit and 32-bit) on the local machine.
        It is designed to be executed remotely via Invoke-Command.

    .EXAMPLE
        Get-LocalSoftwareInventory

        Returns a list of installed software on the local machine.

    .NOTES
        This is a private function not exported from the module.
    #>

    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    $UninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Results = @()

    foreach ($Path in $UninstallPaths) {
        # Check if path exists (crucial for older 32-bit OS or specific configs)
        if (Test-Path $Path) {
            Get-ItemProperty $Path -ErrorAction SilentlyContinue |
            Where-Object { $null -ne $_.DisplayName } |
            ForEach-Object {
                $Results += [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    Name         = $_.DisplayName
                    Version      = $_.DisplayVersion
                    Publisher    = $_.Publisher
                    InstallDate  = $_.InstallDate
                    Architecture = if ($Path -like "*Wow6432Node*") {"32-bit"} else {"64-bit"}
                }
            }
        }
    }
    return $Results
}
