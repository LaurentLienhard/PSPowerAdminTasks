class DNS
{
    #region <Properties>
    [System.String]$ComputerName
    [System.String]$Status
    [System.DateTime]$CheckTime

    HIDDEN [System.Management.Automation.PSCredential]$Credential
    HIDDEN [System.Object]$CimSession
    #endregion <Properties>

    #region <Constructor>
    DNS()
    {
    }

    DNS([string]$ComputerName)
    {
        $this.ComputerName = $ComputerName
        $this.CheckTime = Get-Date
        $this.Initialize()
    }

    DNS([string]$ComputerName, [System.Management.Automation.PSCredential]$Credential)
    {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.CheckTime = Get-Date
        $this.Initialize()
    }
    #endregion <Constructor>

    #region <Methods>
    [void] Initialize()
    {
        Write-Verbose "Initializing DNS connection to $($this.ComputerName)"
        try
        {
            $sessionParams = @{
                ComputerName = $this.ComputerName
                ErrorAction  = 'Stop'
            }
            if ($null -ne $this.Credential)
            {
                $sessionParams['Credential'] = $this.Credential
            }
            $this.CimSession = New-CimSession @sessionParams
            $this.Status = "Connected"
        }
        catch
        {
            $this.Status = "Connection Failed"
            Write-Warning "Failed to connect to DNS server $($this.ComputerName): $($_.Exception.Message)"
        }
    }

    [System.Object[]] GetAllZones()
    {
        if ($this.Status -ne "Connected")
        {
            Write-Warning "DNS server is not connected. Cannot retrieve zones."
            return @()
        }

        Write-Verbose "Retrieving DNS zones from $($this.ComputerName)"
        try
        {
            $zoneParams = @{
                CimSession  = $this.CimSession
                ErrorAction = 'Stop'
            }
            $zones = Get-DnsServerZone @zoneParams
            return @($zones)
        }
        catch
        {
            Write-Warning "Failed to retrieve zones: $($_.Exception.Message)"
            return @()
        }
    }

    [System.Object[]] GetZone([string]$ZoneName)
    {
        if ($this.Status -ne "Connected")
        {
            Write-Warning "DNS server is not connected. Cannot retrieve zones."
            return @()
        }

        Write-Verbose "Retrieving DNS zone: $ZoneName from $($this.ComputerName)"
        try
        {
            $zoneParams = @{
                CimSession  = $this.CimSession
                ZoneName    = $ZoneName
                ErrorAction = 'Stop'
            }
            $zone = Get-DnsServerZone @zoneParams
            return @($zone)
        }
        catch
        {
            Write-Warning "Failed to retrieve zone: $($_.Exception.Message)"
            return @()
        }
    }

    [System.Object[]] FindDuplicateEntries([System.Object[]]$Zones)
    {
        if ($this.Status -ne "Connected")
        {
            Write-Warning "DNS server is not connected. Cannot search for duplicates."
            return @()
        }

        Write-Verbose "Searching for duplicate DNS entries on $($this.ComputerName)"

        $recordTypes = @('A', 'AAAA', 'CNAME', 'MX', 'SRV')
        $allRecords = @()

        # Collect all records first
        foreach ($zone in $Zones)
        {
            Write-Verbose "Processing zone: $($zone.ZoneName)"

            try
            {
                $records = Get-DnsServerResourceRecord -CimSession $this.CimSession `
                    -ZoneName $zone.ZoneName `
                    -ErrorAction SilentlyContinue

                if ($null -eq $records)
                {
                    Write-Verbose "No records found in zone $($zone.ZoneName)"
                    continue
                }

                Write-Verbose "Total records retrieved in $($zone.ZoneName): $($records.Count)"

                foreach ($record in $records)
                {
                    if ($record.RecordType -in $recordTypes)
                    {
                        $dataValue = "N/A"

                        # Extract data based on record type
                        switch ($record.RecordType)
                        {
                            'A'     { $dataValue = $record.RecordData.IPv4Address.IPAddressToString }
                            'AAAA'  { $dataValue = $record.RecordData.IPv6Address.IPAddressToString }
                            'CNAME' { $dataValue = $record.RecordData.HostNameAlias }
                            'MX'    { $dataValue = $record.RecordData.MailExchange }
                            'SRV'   { $dataValue = "$($record.RecordData.DomainName):$($record.RecordData.Port)" }
                        }

                        $allRecords += [PSCustomObject]@{
                            ComputerName = $this.ComputerName
                            ZoneName     = $zone.ZoneName
                            HostName     = $record.HostName
                            RecordType   = $record.RecordType
                            IP_Target    = $dataValue
                            Timestamp    = if ($null -eq $record.Timestamp) { "Static" } else { $record.Timestamp }
                        }
                    }
                }
            }
            catch
            {
                Write-Warning "Error processing zone $($zone.ZoneName): $($_.Exception.Message)"
            }
        }

        # Group by IP_Target and RecordType to find duplicates
        $duplicates = @()
        $grouped = $allRecords | Group-Object -Property IP_Target, RecordType

        foreach ($group in $grouped)
        {
            if ($group.Count -gt 1)
            {
                Write-Verbose "Found $($group.Count) entries for IP/RecordType: $($group.Name)"

                # Get unique hostnames for this IP+RecordType combination
                $hostNames = $group.Group.HostName | Select-Object -Unique
                $hostNameList = $hostNames -join ', '

                $duplicateObj = [PSCustomObject]@{
                    ComputerName   = $this.ComputerName
                    ZoneName       = $group.Group[0].ZoneName
                    HostName       = $hostNameList
                    RecordType     = $group.Group[0].RecordType
                    IP_Target      = $group.Group[0].IP_Target
                    Timestamp      = $group.Group[0].Timestamp
                    DuplicateCount = $group.Count
                }
                $duplicates += $duplicateObj
            }
        }

        return @($duplicates)
    }

    [void] Cleanup()
    {
        if ($null -ne $this.CimSession)
        {
            Write-Verbose "Closing CIM session for $($this.ComputerName)"
            Remove-CimSession $this.CimSession -ErrorAction SilentlyContinue
            $this.CimSession = $null
            $this.Status = "Disconnected"
        }
    }
    #endregion <Methods>
}
