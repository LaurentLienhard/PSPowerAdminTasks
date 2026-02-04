function Find-DnsDuplicateEntries {
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
Find-DnsDuplicateEntries -ComputerName "DNS01" -ZoneName "contoso.com" -Verbose

.NOTES
This function is part of the PSPowerAdminTasks module.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$ZoneName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    Begin {
        $AllDuplicates = [System.Collections.Generic.List[PSObject]]::new()
        # Define types to analyze for duplicates
        $RecordTypes = @('A', 'AAAA', 'CNAME', 'MX', 'SRV')
    }

    Process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Connecting to DNS server: $computer"
            $session = $null

            try {
                $sessionParams = @{
                    ComputerName = $computer
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $sessionParams['Credential'] = $Credential
                }
                $session = New-CimSession @sessionParams

                $zoneParams = @{
                    CimSession  = $session
                    ErrorAction = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('ZoneName')) {
                    $zoneParams['ZoneName'] = $ZoneName
                }

                $zones = Get-DnsServerZone @zoneParams

                foreach ($zone in $zones) {
                    Write-Verbose "Processing zone: $($zone.ZoneName)"

                    # Fetching all records without RRType filter to avoid CIM serialization issues
                    $records = Get-DnsServerResourceRecord -CimSession $session -ZoneName $zone.ZoneName -ErrorAction SilentlyContinue

                    if ($null -eq $records) {
                        Write-Verbose "No records found in zone $($zone.ZoneName)"
                        continue
                    }

                    Write-Verbose "Total records retrieved in $($zone.ZoneName): $($records.Count)"

                    # Group by HostName and RecordType to identify duplicates
                    $grouped = $records | Where-Object { $_.RecordType -in $RecordTypes } | Group-Object -Property HostName, RecordType

                    foreach ($group in $grouped) {
                        if ($group.Count -gt 1) {
                            Write-Verbose "Found $($group.Count) entries for $($group.Name)"

                            foreach ($record in $group.Group) {
                                $dataValue = "N/A"

                                # Extract data based on the specific object property available in CIM
                                switch ($record.RecordType) {
                                    'A'     { $dataValue = $record.RecordData.IPv4Address.IPAddressToString }
                                    'AAAA'  { $dataValue = $record.RecordData.IPv6Address.IPAddressToString }
                                    'CNAME' { $dataValue = $record.RecordData.HostNameAlias }
                                    'MX'    { $dataValue = $record.RecordData.MailExchange }
                                    'SRV'   { $dataValue = "$($record.RecordData.DomainName):$($record.RecordData.Port)" }
                                }

                                $duplicateObj = [PSCustomObject]@{
                                    ComputerName   = $computer
                                    ZoneName       = $zone.ZoneName
                                    HostName       = $record.HostName
                                    RecordType     = $record.RecordType
                                    IP_Target      = $dataValue
                                    Timestamp      = if ($null -eq $record.Timestamp) { "Static" } else { $record.Timestamp }
                                    DuplicateCount = $group.Count
                                }
                                $AllDuplicates.Add($duplicateObj)
                            }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Error processing DNS server $computer : $($_.Exception.Message)"
            }
            finally {
                if ($null -ne $session) {
                    Remove-CimSession $session
                }
            }
        }
    }

    End {
        if ($AllDuplicates.Count -gt 0) {
            return $AllDuplicates | Sort-Object -Property ZoneName, HostName
        }
        else {
            Write-Host "No duplicate DNS entries found." -ForegroundColor Green
        }
    }
}
