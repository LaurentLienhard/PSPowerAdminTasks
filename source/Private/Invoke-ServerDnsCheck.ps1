function Invoke-ServerDnsCheck
{
    <#
        .SYNOPSIS
            Helper function to check DNS configuration on servers using parallel processing.

        .DESCRIPTION
            Internal helper that performs parallel DNS checks on servers using PowerShell 7+ capabilities.
            This function processes multiple servers concurrently to improve performance.
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
        [int]$TimeoutSeconds = 2,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 32
    )

    $computers | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $computer = $_
        $DnsServer = $using:DnsServer
        $Credential = $using:Credential
        $TimeoutSeconds = $using:TimeoutSeconds

        try
        {
            # Quick ping test
            if (-not (Test-Connection -ComputerName $computer.Name -Count 1 -TimeoutSeconds $TimeoutSeconds -ErrorAction SilentlyContinue))
            {
                return
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
                return
            }

            $srvObject.GetDnsConfig()

            # Parse and validate DNS servers
            if (-not $srvObject.DnsServers -or $srvObject.DnsServers -in @("None", "Error Retrieving Info"))
            {
                return
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
                [PSCustomObject]@{
                    ComputerName    = $srvObject.Name
                    OperatingSystem = $computer.OperatingSystem
                    Description     = $computer.Description
                    IPv4Address     = $srvObject.IPv4Address
                    ConfiguredDNS   = $srvObject.DnsServers
                    MatchingDNS     = $matchingDns -join ', '
                    Status          = $srvObject.Status
                    LastCheck       = $srvObject.CheckTime
                }
            }
        }
        catch
        {
            # Silently skip servers with errors in parallel context
            return
        }
    } | Where-Object { $null -ne $_ }
}
