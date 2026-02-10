function Invoke-ServerDnsCheckSequential
{
    <#
        .SYNOPSIS
            Helper function to check DNS configuration on servers sequentially.

        .DESCRIPTION
            Internal helper that performs sequential DNS checks on servers for PowerShell 5.1 compatibility.
            This function processes servers one at a time, suitable for environments where parallel processing is unavailable.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Computers,

        [Parameter(Mandatory = $true)]
        [string[]]$DnsServer,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 2
    )

    $results = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($computer in $Computers)
    {
        try
        {
            # Quick ping test
            if (-not (Test-Connection -ComputerName $computer.Name -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue))
            {
                continue
            }

            # Create COMPUTER object for DNS retrieval
            $srvObject = if ($Credential)
            {
                [COMPUTER]::new($computer.Name, $Credential)
            }
            else
            {
                [COMPUTER]::new($computer.Name)
            }

            if ($srvObject.Status -ne "Ping OK")
            {
                continue
            }

            $srvObject.GetDnsConfig()

            # Parse and validate DNS servers
            if (-not $srvObject.DnsServers -or $srvObject.DnsServers -in @("None", "Error Retrieving Info"))
            {
                continue
            }

            # Parse configured DNS servers (handle both single and multiple)
            $configuredDns = @()
            if ($srvObject.DnsServers -and $srvObject.DnsServers -notin @("None", "Error Retrieving Info", "Unknown IP", "Connection Error"))
            {
                $configuredDns = @($srvObject.DnsServers -split ',\s*' |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -and $_ -ne '' })
            }

            # Find matching DNS servers
            $matchingDns = @($configuredDns | Where-Object { $_ -in $DnsServer })

            if ($matchingDns.Count -gt 0)
            {
                $results.Add([PSCustomObject]@{
                    ComputerName    = $srvObject.Name
                    OperatingSystem = $computer.OperatingSystem
                    Description     = $computer.Description
                    IPv4Address     = $srvObject.IPv4Address
                    ConfiguredDNS   = $srvObject.DnsServers
                    MatchingDNS     = $matchingDns -join ', '
                    Status          = $srvObject.Status
                    LastCheck       = $srvObject.CheckTime
                })
            }
        }
        catch
        {
            Write-Verbose "Error processing $($computer.Name): $($_.Exception.Message)"
            continue
        }
    }

    return @($results)
}
