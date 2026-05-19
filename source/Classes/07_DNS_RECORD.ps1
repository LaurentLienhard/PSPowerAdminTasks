class DNSRecord
{
    #region <Properties>
    [System.String]$ComputerName
    [System.String]$ZoneName
    [System.String]$HostName
    [System.String]$RecordType
    [System.String]$RecordData
    [System.UInt32]$TTL
    [System.Boolean]$IsStatic
    [System.Object]$Timestamp
    #endregion <Properties>

    #region <Constructor>
    DNSRecord([object]$Record, [string]$ComputerName, [string]$ZoneName)
    {
        $this.ComputerName = $ComputerName
        $this.ZoneName = $ZoneName
        $this.HostName = $Record.HostName
        $this.RecordType = $Record.RecordType
        $this.TTL = $Record.TTL
        $this.IsStatic = ($null -eq $Record.Timestamp)
        $this.Timestamp = if ($null -eq $Record.Timestamp) { "Static" } else { $Record.Timestamp }
        
        $this.SetRecordData($Record)
    }
    #endregion <Constructor>

    #region <Methods>
    [void] SetRecordData([object]$Record)
    {
        switch ($Record.RecordType)
        {
            'A' { $this.RecordData = $Record.RecordData.IPv4Address.IPAddressToString }
            'AAAA' { $this.RecordData = $Record.RecordData.IPv6Address.IPAddressToString }
            'CNAME' { $this.RecordData = $Record.RecordData.HostNameAlias }
            'MX' { $this.RecordData = "$($Record.RecordData.Preference) $($Record.RecordData.MailExchange)" }
            'NS' { $this.RecordData = $Record.RecordData.NameServer }
            'SOA' { $this.RecordData = "$($Record.RecordData.PrimaryServer) $($Record.RecordData.ResponsiblePerson)" }
            'SRV' { $this.RecordData = "$($Record.RecordData.Priority) $($Record.RecordData.Weight) $($Record.RecordData.Port) $($Record.RecordData.DomainName)" }
            'TXT' { $this.RecordData = $Record.RecordData.DescriptiveText -join ' ' }
            default { $this.RecordData = "See RecordData property" }
        }
    }
    #endregion <Methods>
}
