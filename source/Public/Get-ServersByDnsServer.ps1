function Get-ServersByDnsServer
{
    <#
        .SYNOPSIS
            Lists all active domain servers that use specific DNS servers.

        .DESCRIPTION
            Retrieves all active computers in Active Directory and filters them based on configured DNS servers.
            This function connects to each server to retrieve its DNS configuration from the active network adapter.
            Optimized for large environments (1000+ servers) with parallel processing in PowerShell 7+.

            Returns an array of objects containing server information and matching DNS servers.
            Use -Verbose to see detailed processing information for each server being scanned.

        .PARAMETER DnsServer
            Specifies one or more DNS server IP addresses to search for. The function returns servers configured
            to use any of the specified DNS servers (one or more matches).
            This parameter is mandatory.

        .PARAMETER Server
            Specifies the domain controller to query. If not specified, the default domain controller is used.

        .PARAMETER Credential
            Specifies credentials to use for the query and remote operations. If not specified, the current
            user context is used.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            For high-latency networks or limited resources, reduce this value.
            For fast networks with many cores, increase to 64 or more.
            Only applicable when running on PowerShell 7+.

        .PARAMETER TimeoutSeconds
            Timeout in seconds for ping tests on each server. Default is 2 seconds.
            Range: 1-30 seconds.

        .OUTPUTS
            System.Object[]
            Returns an array of PSCustomObjects with the following properties:
            - ComputerName: Name of the server
            - OperatingSystem: Server operating system
            - Description: Server description from Active Directory
            - IPv4Address: Server IP address (LAN IP, not VPN/NAT)
            - ConfiguredDNS: Comma-separated list of configured DNS servers
            - MatchingDNS: DNS servers from the search criteria that are configured on this server
            - Status: Ping status (e.g., "Ping OK")
            - LastCheck: Timestamp when DNS configuration was retrieved

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15'

            Returns all active servers in the domain that are configured to use either 10.1.3.12 or 10.1.3.15
            as DNS servers. Returns empty array if no servers match.

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -Verbose

            Returns all active servers using DNS server 10.1.3.12 and displays detailed processing information
            for each server being scanned, including which servers are being checked and their ping status.

        .EXAMPLE
            $results = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ThrottleLimit 64
            $results | Select-Object ComputerName, ConfiguredDNS, MatchingDNS

            Scans with 64 parallel operations for faster results on high-bandwidth networks, then displays
            only the server name, configured DNS servers, and matching DNS servers.

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -WhatIf

            Shows what servers would be scanned without actually retrieving DNS information.

        .NOTES
            - Returns always an array (@()), even if no servers match or an error occurs
            - Parallel processing requires PowerShell 7+; PS 5.1 uses sequential processing with a warning
            - Uses the COMPUTER class for DNS retrieval with support for remote credentials
            - Servers that don't respond to ping are skipped silently
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DnsServer,

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 30)]
        [int]$TimeoutSeconds = 2
    )

    BEGIN
    {
        # Initialize results array
        $results = @()

        # Check PowerShell version for parallel processing capability
        $useParallel = $PSVersionTable.PSVersion.Major -ge 7

        if (-not $useParallel)
        {
            Write-Verbose "PowerShell 7+ is recommended for optimal performance with large server counts (1000+)"
        }

        # Validate AD module
        if (-not (Get-Module -Name ActiveDirectory))
        {
            try
            {
                Import-Module ActiveDirectory -ErrorAction Stop
            }
            catch
            {
                Write-Error "Failed to import Active Directory module: $_"
                return
            }
        }

        # Build AD parameters
        $adParams = @{ ErrorAction = 'Stop' }
        if ($Server)
        {
            $adParams['Server'] = $Server
        }
        if ($Credential)
        {
            $adParams['Credential'] = $Credential
        }

        Write-Verbose "Searching for servers with DNS servers: $($DnsServer -join ', ')"
        Write-Verbose "Using ThrottleLimit: $ThrottleLimit, TimeoutSeconds: $TimeoutSeconds, Parallel: $useParallel"
    }

    PROCESS
    {
        try
        {
            # Retrieve all active computers from AD
            Write-Verbose "Retrieving all active computers from Active Directory..."

            $computers = Get-ADComputer -Filter { Enabled -eq $true } @adParams -Properties OperatingSystem, Description -ErrorAction Stop

            if (-not $computers)
            {
                Write-Verbose "No active computers found in Active Directory"
                return @()
            }

            Write-Verbose "Found $($computers.Count) active computers. Checking DNS configuration..."

            if (-not $PSCmdlet.ShouldProcess("Scan $($computers.Count) servers for DNS configuration", "Scan servers"))
            {
                return @()
            }

            $startTime = Get-Date

            # Choose processing method based on PowerShell version
            if ($useParallel)
            {
                $results = Invoke-ServerDnsCheck -Computers $computers -DnsServer $DnsServer -Credential $Credential `
                    -TimeoutSeconds $TimeoutSeconds -ThrottleLimit $ThrottleLimit
            }
            else
            {
                $results = Invoke-ServerDnsCheckSequential -Computers $computers -DnsServer $DnsServer `
                    -Credential $Credential -TimeoutSeconds $TimeoutSeconds
            }

            $endTime = Get-Date
            $duration = $endTime - $startTime

            Write-Verbose "Scan completed in $($duration.TotalSeconds) seconds"
            if ($results -and $results.Count -gt 0)
            {
                Write-Verbose "Found $($results.Count) servers matching the DNS criteria"
            }
            else
            {
                Write-Verbose "No servers found matching the DNS criteria"
            }
        }
        catch
        {
            Write-Error "Fatal error retrieving servers: $($_.Exception.Message)"
        }
    }

    END
    {
        return $results
    }
}
