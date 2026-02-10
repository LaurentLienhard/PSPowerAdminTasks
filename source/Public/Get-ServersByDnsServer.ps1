function Get-ServersByDnsServer
{
    <#
        .SYNOPSIS
            Lists all active domain servers that use specific DNS servers.

        .DESCRIPTION
            Retrieves all active computers in Active Directory and filters them based on configured DNS servers.
            This function connects to each server to retrieve its DNS configuration from the active network adapter.
            Optimized for large environments (1000+ servers) with parallel processing in PowerShell 7+.

        .PARAMETER DnsServer
            Specifies one or more DNS server IP addresses to search for. The function returns servers configured
            to use any of the specified DNS servers.

        .PARAMETER Server
            Specifies the domain controller to query. If not specified, the default domain controller is used.

        .PARAMETER Credential
            Specifies credentials to use for the query and remote operations. If not specified, the current
            user context is used.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            For high-latency networks or limited resources, reduce this value.
            For fast networks with many cores, increase to 64 or more.

        .PARAMETER TimeoutSeconds
            Timeout in seconds for ping tests on each server. Default is 2 seconds.

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15'

            Returns all active servers in the domain that are configured to use either 10.1.3.12 or 10.1.3.15 as DNS servers.

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -ThrottleLimit 64

            Scans with 64 parallel operations for faster results on high-bandwidth networks.

        .EXAMPLE
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -WhatIf

            Shows what servers would be returned without actually retrieving DNS information.
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
