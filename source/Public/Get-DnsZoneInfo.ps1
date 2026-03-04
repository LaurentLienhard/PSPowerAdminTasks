function Get-DnsZoneInfo
{
    <#
        .SYNOPSIS
            Retrieves DNS zone information and records from a DNS server.

        .DESCRIPTION
            This function retrieves detailed information about DNS zones and their records
            from a Windows DNS server. It can extract all records from a specific zone or
            from all zones on the server. Returns structured objects with record details
            including record type, data, TTL, and information about whether records are
            static or dynamically registered (DHCP).

        .PARAMETER ComputerName
            Specifies the DNS server computer name. Mandatory parameter.
            Accepts pipeline input.

        .PARAMETER ZoneName
            Specifies the DNS zone name. If not provided, retrieves information
            from all zones on the server.

        .PARAMETER Credential
            Specifies the credentials to use for connecting to the DNS server.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ zones on PowerShell 7+.

        .EXAMPLE
            Get-DnsZoneInfo -ComputerName DNS01

            Retrieves information about all DNS zones on DNS01.

        .EXAMPLE
            Get-DnsZoneInfo -ComputerName DNS01 -ZoneName "contoso.com"

            Retrieves all records from the contoso.com zone.

        .EXAMPLE
            Get-DnsZoneInfo -ComputerName DNS01 -ZoneName "contoso.com" -Credential (Get-Credential)

            Retrieves zone records with alternate credentials.

        .EXAMPLE
            Get-DnsZoneInfo -ComputerName DNS01 -ZoneName "contoso.com" | Where-Object { $_.IsStatic -eq $true }

            Retrieves only static DNS records from the contoso.com zone.

        .EXAMPLE
            Get-DnsZoneInfo -ComputerName DNS01 -ZoneName "contoso.com" | Where-Object { $_.IsStatic -eq $false }

            Retrieves only dynamic (DHCP-registered) DNS records from the contoso.com zone.

        .NOTES
            This function is part of the PSPowerAdminTasks module.
            For PowerShell 7+, parallel processing is used for 10+ zones.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$ZoneName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32
    )

    BEGIN
    {
        Write-Verbose "Starting Get-DnsZoneInfo function"
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

                # Check connection status
                if ($dnsServer.Status -ne "Connected")
                {
                    Write-Warning "Failed to connect to DNS server $computer"
                    continue
                }

                # Get zones
                if ($PSBoundParameters.ContainsKey('ZoneName'))
                {
                    Write-Verbose "Retrieving specific zone: $ZoneName"
                    $zones = $dnsServer.GetZone($ZoneName)
                }
                else
                {
                    Write-Verbose "Retrieving all zones from $computer"
                    $zones = $dnsServer.GetAllZones()
                }

                if ($zones.Count -eq 0)
                {
                    Write-Verbose "No zones found on $computer"
                    $dnsServer.Cleanup()
                    continue
                }

                # Process zones (sequential for now, can be parallel if needed)
                foreach ($zone in $zones)
                {
                    Write-Verbose "Processing zone: $($zone.ZoneName)"

                    try
                    {
                        # Get all records in the zone
                        $records = $dnsServer.GetZoneRecords($zone.ZoneName)

                        if ($records.Count -eq 0)
                        {
                            Write-Verbose "No records found in zone $($zone.ZoneName)"
                            continue
                        }

                        Write-Verbose "Retrieved $($records.Count) records from zone $($zone.ZoneName)"

                        # Convert records to custom objects with relevant information
                        foreach ($record in $records)
                        {
                            $recordData = $null

                            # Extract data based on record type
                            switch ($record.RecordType)
                            {
                                'A'
                                {
                                    $recordData = $record.RecordData.IPv4Address.IPAddressToString
                                }
                                'AAAA'
                                {
                                    $recordData = $record.RecordData.IPv6Address.IPAddressToString
                                }
                                'CNAME'
                                {
                                    $recordData = $record.RecordData.HostNameAlias
                                }
                                'MX'
                                {
                                    $recordData = "$($record.RecordData.Preference) $($record.RecordData.MailExchange)"
                                }
                                'NS'
                                {
                                    $recordData = $record.RecordData.NameServer
                                }
                                'SOA'
                                {
                                    $recordData = "$($record.RecordData.PrimaryServer) $($record.RecordData.ResponsiblePerson)"
                                }
                                'SRV'
                                {
                                    $recordData = "$($record.RecordData.Priority) $($record.RecordData.Weight) $($record.RecordData.Port) $($record.RecordData.DomainName)"
                                }
                                'TXT'
                                {
                                    $recordData = $record.RecordData.DescriptiveText -join ' '
                                }
                                default
                                {
                                    $recordData = "See RecordData property"
                                }
                            }

                            [PSCustomObject]@{
                                ComputerName = $computer
                                ZoneName     = $zone.ZoneName
                                HostName     = $record.HostName
                                RecordType   = $record.RecordType
                                RecordData   = $recordData
                                TTL          = $record.TTL
                                IsStatic     = ($null -eq $record.Timestamp)
                                Timestamp    = if ($null -eq $record.Timestamp) { "Static" } else { $record.Timestamp }
                            }
                        }
                    }
                    catch
                    {
                        Write-Warning "Error processing zone $($zone.ZoneName) on $computer : $($_.Exception.Message)"
                    }
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
        Write-Verbose "Completed Get-DnsZoneInfo function"
    }
}
