function Get-RemoteRebootLog
{
    <#
        .SYNOPSIS
            Retrieves reboot logs from a remote server with readable reason codes.

        .DESCRIPTION
            This function queries the System event log on remote servers for reboot events.
            It translates raw event codes into human-readable reasons and processes multiple
            servers efficiently using parallel processing in PowerShell 7+.

        .PARAMETER ComputerName
            Specifies the name of the computer(s) to check. Accepts pipeline input and multiple values.

        .PARAMETER Credential
            Specifies credentials for remote connections.

        .PARAMETER MaxEvents
            Maximum number of reboot events to retrieve per computer. Default is 50.

        .PARAMETER StartTime
            Filter events after this date. Default is 30 days ago.

        .PARAMETER ThrottleLimit
            Specifies the maximum number of parallel operations. Default is 32.
            Only applicable when processing 10+ computers on PowerShell 7+.

        .PARAMETER TimeoutSeconds
            Timeout in seconds for WinEvent queries. Default is 10 seconds.

        .EXAMPLE
            Get-RemoteRebootLog -ComputerName Server01, Server02

        .EXAMPLE
            Get-RemoteRebootLog -ComputerName (Get-Content servers.txt) -ThrottleLimit 64

        .NOTES
            Requires PowerShell 7+ for optimal performance with multiple computers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MaxEvents = 50,

        [Parameter()]
        [datetime]$StartTime = (Get-Date).AddDays(-30),

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 32,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 10
    )

    BEGIN
    {
        Write-Verbose "Starting reboot log search"

        # Detect PowerShell version for parallel processing capability
        $useParallel = ($PSVersionTable.PSVersion.Major -ge 7) -and ($ComputerName.Count -ge 10)

        if (-not $useParallel -and ($PSVersionTable.PSVersion.Major -lt 7) -and ($ComputerName.Count -ge 10))
        {
            Write-Verbose "Running on PowerShell 5.1 with 10+ computers. Consider upgrading to PowerShell 7+ for parallel processing."
        }

        Write-Verbose "Processing $($ComputerName.Count) computers. Parallel: $useParallel, ThrottleLimit: $ThrottleLimit"

        # Event IDs for reboots
        $eventIDs = @(1074, 6006, 6008, 1076)

        # Reason code mapping
        $reasonMap = @{
            '0x00000000' = 'Other (Unplanned)'
            '0x40000000' = 'Other (Unplanned)'
            '0x80000000' = 'Other (Planned)'
            '0x40010004' = 'System: Maintenance (Planned)'
            '0x40000015' = 'OS: Upgrade (Planned)'
            '0x80020002' = 'OS: Recovery (Planned)'
            '0x80020010' = 'OS: Service Pack (Planned)'
            '0x8003000f' = 'OS: Hotfix Installation (Planned)'
            '0x80030002' = 'OS: Hotfix Installation (Planned)'
            '0x41000000' = 'Hardware Problem (Unplanned)'
            '0x00050000' = 'System Failure (Stop Error - BSOD)'
            '0x800000ff' = 'System Idle / Sleep'
            '0x00040000' = 'Application Problem (Unplanned)'
            '0x80040002' = 'Application: Installation (Planned)'
            '0x80040005' = 'Application: Maintenance (Planned)'
            '0x00020000' = 'Security Problem'
            '0x8002000e' = 'Security: Credential Update (Planned)'
            '0x20000000' = 'Shutdown via API (Software)'
        }
    }

    PROCESS
    {
        if ($useParallel)
        {
            # PowerShell 7+ - Parallel processing
            $ComputerName | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $computer = $_
                $Credential = $using:Credential
                $MaxEvents = $using:MaxEvents
                $StartTime = $using:StartTime
                $eventIDs = $using:eventIDs
                $reasonMap = $using:reasonMap
                $TimeoutSeconds = $using:TimeoutSeconds

                try
                {
                    Write-Verbose "Connecting to $computer..."

                    $filterHash = @{
                        LogName   = 'System'
                        ID        = $eventIDs
                        StartTime = $StartTime
                    }

                    $getWinEventParams = @{
                        ComputerName    = $computer
                        FilterHashtable = $filterHash
                        MaxEvents       = $MaxEvents
                        ErrorAction     = 'Stop'
                    }

                    if ($Credential)
                    {
                        $getWinEventParams.Add('Credential', $Credential)
                    }

                    $events = Get-WinEvent @getWinEventParams

                    if ($events)
                    {
                        Write-Verbose "Found $($events.Count) reboot event(s) on $computer"

                        foreach ($rebootEvent in $events)
                        {
                            $properties = @{
                                TimeCreated = $rebootEvent.TimeCreated
                                EventID     = $rebootEvent.Id
                                Computer    = $rebootEvent.MachineName
                                User        = 'N/A'
                                Reason      = 'N/A'
                                Process     = 'N/A'
                                Comment     = 'N/A'
                                Type        = 'N/A'
                            }

                            switch ($rebootEvent.Id)
                            {
                                1074
                                {
                                    $properties.Type = 'Initiated Shutdown/Restart'
                                    $xml = [xml]$rebootEvent.ToXml()
                                    $eventData = $xml.Event.EventData.Data

                                    if ($eventData)
                                    {
                                        $properties.User = $eventData[6].InnerText
                                        $properties.Process = $eventData[0].InnerText
                                        $rawReason = $eventData[2].InnerText
                                        $properties.Reason = if ($reasonMap.ContainsKey($rawReason)) { "$rawReason ($($reasonMap[$rawReason]))" } else { $rawReason }
                                        $properties.Comment = $eventData[5].InnerText
                                        $shutdownType = $eventData[4].InnerText
                                        if ($shutdownType -eq 'restart') { $properties.Type = 'Restart' }
                                        elseif ($shutdownType -eq 'power off') { $properties.Type = 'Shutdown' }
                                    }
                                }

                                6006
                                {
                                    $properties.Type = 'Clean Shutdown'
                                    $properties.Reason = 'Event Log service stopped'
                                }

                                6008
                                {
                                    $properties.Type = 'Unexpected Shutdown'
                                    $properties.Reason = 'System unexpectedly shut down (crash/failure)'

                                    if ($rebootEvent.Properties)
                                    {
                                        $properties.Comment = "Last known boot time: $($rebootEvent.Properties[0].Value) $($rebootEvent.Properties[1].Value)"
                                    }
                                }

                                1076
                                {
                                    $properties.Type = 'Shutdown Reason Info'
                                    $xml = [xml]$rebootEvent.ToXml()
                                    $eventData = $xml.Event.EventData.Data

                                    if ($eventData)
                                    {
                                        $properties.User = $eventData[3].InnerText
                                        $rawReason = $eventData[4].InnerText
                                        $properties.Reason = if ($reasonMap.ContainsKey($rawReason)) { "$rawReason ($($reasonMap[$rawReason]))" } else { $rawReason }
                                        $properties.Comment = $eventData[5].InnerText
                                    }
                                }
                            }

                            [PSCustomObject]$properties
                        }
                    }
                    else
                    {
                        Write-Verbose "No reboot events found on $computer since $StartTime"
                    }
                }
                catch
                {
                    Write-Verbose "Error processing $computer : $($_.Exception.Message)"
                }
            } | Where-Object { $null -ne $_ }
        }
        else
        {
            # Sequential processing for PS 5.1 or small counts
            Write-Verbose "Processing $($ComputerName.Count) computers sequentially..."

            foreach ($computer in $ComputerName)
            {
                try
                {
                    Write-Verbose "Connecting to $computer..."

                    $filterHash = @{
                        LogName   = 'System'
                        ID        = $eventIDs
                        StartTime = $StartTime
                    }

                    $getWinEventParams = @{
                        ComputerName    = $computer
                        FilterHashtable = $filterHash
                        MaxEvents       = $MaxEvents
                        ErrorAction     = 'Stop'
                    }

                    if ($Credential)
                    {
                        $getWinEventParams.Add('Credential', $Credential)
                    }

                    $events = Get-WinEvent @getWinEventParams

                    if ($events)
                    {
                        Write-Verbose "Found $($events.Count) reboot event(s) on $computer"

                        foreach ($rebootEvent in $events)
                        {
                            $properties = @{
                                TimeCreated = $rebootEvent.TimeCreated
                                EventID     = $rebootEvent.Id
                                Computer    = $rebootEvent.MachineName
                                User        = 'N/A'
                                Reason      = 'N/A'
                                Process     = 'N/A'
                                Comment     = 'N/A'
                                Type        = 'N/A'
                            }

                            switch ($rebootEvent.Id)
                            {
                                1074
                                {
                                    $properties.Type = 'Initiated Shutdown/Restart'
                                    $xml = [xml]$rebootEvent.ToXml()
                                    $eventData = $xml.Event.EventData.Data

                                    if ($eventData)
                                    {
                                        $properties.User = $eventData[6].InnerText
                                        $properties.Process = $eventData[0].InnerText
                                        $rawReason = $eventData[2].InnerText
                                        $properties.Reason = if ($reasonMap.ContainsKey($rawReason)) { "$rawReason ($($reasonMap[$rawReason]))" } else { $rawReason }
                                        $properties.Comment = $eventData[5].InnerText
                                        $shutdownType = $eventData[4].InnerText
                                        if ($shutdownType -eq 'restart') { $properties.Type = 'Restart' }
                                        elseif ($shutdownType -eq 'power off') { $properties.Type = 'Shutdown' }
                                    }
                                }

                                6006
                                {
                                    $properties.Type = 'Clean Shutdown'
                                    $properties.Reason = 'Event Log service stopped'
                                }

                                6008
                                {
                                    $properties.Type = 'Unexpected Shutdown'
                                    $properties.Reason = 'System unexpectedly shut down (crash/failure)'

                                    if ($rebootEvent.Properties)
                                    {
                                        $properties.Comment = "Last known boot time: $($rebootEvent.Properties[0].Value) $($rebootEvent.Properties[1].Value)"
                                    }
                                }

                                1076
                                {
                                    $properties.Type = 'Shutdown Reason Info'
                                    $xml = [xml]$rebootEvent.ToXml()
                                    $eventData = $xml.Event.EventData.Data

                                    if ($eventData)
                                    {
                                        $properties.User = $eventData[3].InnerText
                                        $rawReason = $eventData[4].InnerText
                                        $properties.Reason = if ($reasonMap.ContainsKey($rawReason)) { "$rawReason ($($reasonMap[$rawReason]))" } else { $rawReason }
                                        $properties.Comment = $eventData[5].InnerText
                                    }
                                }
                            }

                            [PSCustomObject]$properties
                        }
                    }
                    else
                    {
                        Write-Verbose "No reboot events found on $computer since $StartTime"
                    }
                }
                catch [System.Exception]
                {
                    if ($_.Exception.Message -like "*No events were found*")
                    {
                        Write-Verbose "No reboot events found on $computer since $StartTime"
                    }
                    elseif ($_.Exception.Message -like "*The RPC server is unavailable*")
                    {
                        Write-Error "Unable to connect to $computer. Check firewall/WinRM settings."
                    }
                    elseif ($_.Exception.Message -like "*Access is denied*")
                    {
                        Write-Error "Access denied on $computer. Check your permissions."
                    }
                    else
                    {
                        Write-Error "Error on $computer : $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    END
    {
        Write-Verbose "Reboot log search completed"
    }
}
