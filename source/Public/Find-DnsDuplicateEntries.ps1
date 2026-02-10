function Find-DnsDuplicateEntries
{
    <#
    .SYNOPSIS
        Finds duplicate DNS entries on Windows DNS servers.

    .DESCRIPTION
        This function searches for duplicate DNS records on a Windows DNS server.
        It returns objects containing IP address, record name, timestamp, and record type
        for any duplicate entries found.

    .PARAMETER ComputerName
        Specifies the target DNS server computer name.

    .PARAMETER ZoneName
        Specifies the DNS zone name to search. If not provided, searches all zones.

    .PARAMETER Credential
        Specifies a user account that has permissions to query the DNS server.

    .EXAMPLE
        Find-DnsDuplicateEntries -ComputerName "DNS01"

    .EXAMPLE
        Find-DnsDuplicateEntries -ComputerName "DNS01" -ZoneName "contoso.com"

    .NOTES
        This function is part of the PSPowerAdminTasks module.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$ZoneName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        $AllDuplicates = @()
    }

    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose "Processing DNS server: $computer"

            try
            {
                # Create DNS object instance
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $dnsServer = [DNS]::new($computer, $Credential)
                }
                else
                {
                    $dnsServer = [DNS]::new($computer)
                }

                if ($dnsServer.Status -ne "Connected")
                {
                    Write-Warning "Failed to connect to DNS server $computer"
                    continue
                }

                # Get zones
                if ($PSBoundParameters.ContainsKey('ZoneName'))
                {
                    $zones = $dnsServer.GetZone($ZoneName)
                }
                else
                {
                    $zones = $dnsServer.GetAllZones()
                }

                if ($zones.Count -eq 0)
                {
                    Write-Verbose "No zones found on $computer"
                    $dnsServer.Cleanup()
                    continue
                }

                # Find duplicates
                $duplicates = $dnsServer.FindDuplicateEntries($zones)

                foreach ($duplicate in $duplicates)
                {
                    $AllDuplicates += $duplicate
                }

                # Cleanup
                $dnsServer.Cleanup()
            }
            catch
            {
                Write-Warning "Error processing DNS server $computer : $($_.Exception.Message)"
            }
        }
    }

    END
    {
        if ($AllDuplicates.Count -gt 0)
        {
            return $AllDuplicates | Sort-Object -Property ZoneName, HostName
        }
        else
        {
            Write-Verbose "No duplicate DNS entries found."
        }
    }
}
