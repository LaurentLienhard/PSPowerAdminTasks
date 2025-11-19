function Get-RemoteSoftware {
    <#
    .SYNOPSIS
        Retrieves the list of installed software from remote servers via the Registry.

    .DESCRIPTION
        This function uses PowerShell Remoting (Invoke-Command) to query the Uninstall registry keys
        (HKLM and Wow6432Node) on remote machines.
        It is designed to be fast, safe, and compatible with Windows Server 2008 through 2022.

    .PARAMETER ComputerName
        One or more server names or IP addresses.
        Accepts input from the pipeline.

    .PARAMETER Credential
        A PSCredential object to authenticate on the remote servers.
        If omitted, the current session credentials will be used.

    .EXAMPLE
        Get-RemoteSoftware -ComputerName "SRV-DB01"

    .EXAMPLE
        Get-RemoteSoftware -ComputerName "SRV-WEB01", "SRV-WEB02" -Credential (Get-Credential)

    .EXAMPLE
        Get-ADComputer -Filter * | Get-RemoteSoftware | Export-Csv "SoftwareInventory.csv"
    .EXAMPLE
        Get-ADComputer -Filter {OperatingSystem -like "*Server*"} | Select-Object -ExpandProperty Name | Get-RemoteSoftware -Credential (Get-Credential) |
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true,
                   Position = 0)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN {
        # Define the script block to run on remote machines once
        $ScriptBlock = {
            $UninstallPaths = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )

            $Results = @()

            foreach ($Path in $UninstallPaths) {
                # Check if path exists (crucial for older 32-bit OS or specific configs)
                if (Test-Path $Path) {
                    Get-ItemProperty $Path -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -ne $null } |
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
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Connecting to $Computer..."

            $InvokeParams = @{
                ComputerName = $Computer
                ScriptBlock  = $ScriptBlock
                ErrorAction  = 'Stop'
            }

            if ($Credential) {
                $InvokeParams.Add('Credential', $Credential)
            }

            try {
                # Execute remotely
                $Data = Invoke-Command @InvokeParams

                # Select specific properties to clean up the object (removes PSComputerName, RunspaceId, etc.)
                $Data | Select-Object ComputerName, Name, Version, Publisher, InstallDate, Architecture

            } catch {
                Write-Error "Failed to retrieve software from $Computer : $($_.Exception.Message)"
            }
        }
    }

    END {
        Write-Verbose "Operation complete."
    }
}
