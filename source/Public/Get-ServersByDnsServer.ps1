<#
.SYNOPSIS
Lists all active domain servers that use specific DNS servers.

.DESCRIPTION
Retrieves all active computers in Active Directory and filters them based on configured DNS servers.
This function connects to each server to retrieve its DNS configuration from the active network adapter.

.PARAMETER DnsServer
Specifies one or more DNS server IP addresses to search for. The function returns servers configured
to use any of the specified DNS servers.

.PARAMETER Server
Specifies the domain controller to query. If not specified, the default domain controller is used.

.PARAMETER Credential
Specifies credentials to use for the query and remote operations. If not specified, the current
user context is used.

.EXAMPLE
Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15'

Returns all active servers in the domain that are configured to use either 10.1.3.12 or 10.1.3.15 as DNS servers.

.EXAMPLE
Get-ServersByDnsServer -DnsServer '10.1.3.12' -Credential (Get-Credential)

Returns all servers using 10.1.3.12 as DNS, using specified credentials.

.NOTES
This function is part of the PSPowerAdminTasks module.
Requires Active Directory module and network connectivity to target servers.
#>
function Get-ServersByDnsServer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DnsServer,

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        # Check module
        if (-not (Get-Module -Name ActiveDirectory))
        {
            Import-Module ActiveDirectory -ErrorAction Stop
        }

        $adParams = @{ ErrorAction = 'Stop' }
        if ($Server)
        {
            $adParams['Server'] = $Server
        }
        if ($Credential)
        {
            $adParams['Credential'] = $Credential
        }

        $AllResults = [System.Collections.Generic.List[PSObject]]::new()

        Write-Verbose "Searching for servers with DNS servers: $($DnsServer -join ', ')"
    }

    PROCESS
    {
        try
        {
            # Get all active computers in the domain
            Write-Verbose "Retrieving all active computers from Active Directory..."
            $computers = Get-ADComputer -Filter { Enabled -eq $true } @adParams -Properties OperatingSystem, Description

            Write-Verbose "Found $($computers.Count) active computers. Checking DNS configuration..."

            foreach ($computer in $computers)
            {
                try
                {
                    Write-Verbose "Processing $($computer.Name)..."

                    # Create COMPUTER object to get DNS info
                    if ($Credential)
                    {
                        $srvObject = [COMPUTER]::new($computer.Name, $Credential)
                    }
                    else
                    {
                        $srvObject = [COMPUTER]::new($computer.Name)
                    }

                    # Check if computer is online and get DNS config
                    if ($srvObject.Status -eq "Ping OK")
                    {
                        $srvObject.GetDnsConfig()

                        # Parse DNS servers from the string (format: "IP1, IP2, IP3")
                        if ($srvObject.DnsServers -and $srvObject.DnsServers -ne "None" -and $srvObject.DnsServers -ne "Error Retrieving Info")
                        {
                            $configuredDns = @($srvObject.DnsServers -split ',\s*' | ForEach-Object { $_.Trim() })

                            # Check if any of the configured DNS servers match our search criteria
                            $matchingDns = $configuredDns | Where-Object { $_ -in $DnsServer }

                            if ($matchingDns)
                            {
                                $resultObj = [PSCustomObject]@{
                                    ComputerName      = $srvObject.Name
                                    OperatingSystem   = $computer.OperatingSystem
                                    Description       = $computer.Description
                                    IPv4Address       = $srvObject.IPv4Address
                                    ConfiguredDNS     = $srvObject.DnsServers
                                    MatchingDNS       = $matchingDns -join ', '
                                    Status            = $srvObject.Status
                                    LastCheck         = $srvObject.CheckTime
                                }

                                $AllResults.Add($resultObj)
                                Write-Verbose "✓ $($computer.Name) - Matches: $($matchingDns -join ', ')"
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "✗ $($computer.Name) - Status: $($srvObject.Status)"
                    }
                }
                catch
                {
                    Write-Verbose "Error processing $($computer.Name): $($_.Exception.Message)"
                }
            }
        }
        catch
        {
            Write-Error "Fatal error retrieving computers from Active Directory: $_"
        }
    }

    END
    {
        Write-Verbose "Found $($AllResults.Count) servers matching the DNS criteria"
        return $AllResults
    }
}
