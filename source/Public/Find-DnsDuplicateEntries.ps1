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
function Find-DnsDuplicateEntries
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$ZoneName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    Begin
    {
        $AllDuplicates = [System.Collections.Generic.List[PSObject]]::new()
    }

    Process
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose "Searching for duplicate DNS entries on $computer..."
            try
            {
                $params = @{
                    ComputerName = $computer
                }

                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $params['Credential'] = $Credential
                }

                if ($PSBoundParameters.ContainsKey('ZoneName')) {
                    $params['ZoneName'] = $ZoneName
                }

                # Get all DNS zones
                $zones = Get-DnsServerZone @params -ErrorAction Stop

                foreach ($zone in $zones)
                {
                    Write-Verbose "Processing zone: $($zone.ZoneName)"

                    # Get all resource records from the zone
                    $records = Get-DnsServerResourceRecord -ComputerName $computer `
                        -ZoneName $zone.ZoneName `
                        -RRType @('A', 'AAAA', 'CNAME', 'MX', 'SRV') `
                        -ErrorAction SilentlyContinue

                    if ($null -eq $records) {
                        continue
                    }

                    # Convert to array if single record
                    if ($records -isnot [System.Collections.IEnumerable]) {
                        $records = @($records)
                    }

                    # Group by HostName and RecordType to find duplicates
                    $grouped = $records | Group-Object -Property HostName, RecordType

                    foreach ($group in $grouped)
                    {
                        if ($group.Count -gt 1)
                        {
                            Write-Verbose "Found $($group.Count) duplicate entries for $($group.Name)"

                            foreach ($record in $group.Group)
                            {
                                $ip = $null
                                $entryType = $record.RecordType

                                # Extract IP based on record type
                                if ($record.RecordType -eq 'A') {
                                    $ip = $record.RecordData.IPv4Address.ToString()
                                }
                                elseif ($record.RecordType -eq 'AAAA') {
                                    $ip = $record.RecordData.IPv6Address.ToString()
                                }
                                elseif ($record.RecordType -eq 'CNAME') {
                                    $ip = $record.RecordData.CanonicalName.ToString()
                                }
                                elseif ($record.RecordType -eq 'MX') {
                                    $ip = $record.RecordData.MailExchange.ToString()
                                }
                                elseif ($record.RecordType -eq 'SRV') {
                                    $ip = "$($record.RecordData.Priority)/$($record.RecordData.Weight)/$($record.RecordData.Port)"
                                }

                                $duplicateObj = [PSCustomObject]@{
                                    ComputerName  = $computer
                                    ZoneName      = $zone.ZoneName
                                    HostName      = $record.HostName
                                    RecordType    = $entryType
                                    IPAddress     = $ip
                                    TimeToLive    = $record.TimeToLive
                                    Timestamp     = Get-Date
                                    DuplicateCount = $group.Count
                                }

                                $AllDuplicates.Add($duplicateObj)
                            }
                        }
                    }
                }
            }
            catch
            {
                Write-Warning "Error processing DNS server $computer : $($_.Exception.Message)"
            }
        }
    }

    End
    {
        if ($AllDuplicates.Count -gt 0)
        {
            return $AllDuplicates | Sort-Object -Property ZoneName, HostName, RecordType
        }
    }
}
