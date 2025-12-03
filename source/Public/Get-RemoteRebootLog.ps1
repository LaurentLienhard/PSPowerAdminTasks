function Get-RemoteRebootLog
{
    <#
    .SYNOPSIS
        Retrieves reboot logs from a remote server.

    .DESCRIPTION
        This function queries the System event log of a remote server to
        identify reboot events (ID 1074, 6006, 6008) and displays who
        initiated the reboot and the reason if available.

    .PARAMETER ComputerName
        Name or IP address of the server to query.

    .PARAMETER Credential
        Credentials to connect to the remote server.
        If not specified, uses the current user's credentials.

    .PARAMETER MaxEvents
        Maximum number of events to retrieve. Default: 50.

    .PARAMETER StartTime
        Start date for the event search. Default: 30 days back.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01"

        Retrieves reboot logs from server SERVER01.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01" -Credential (Get-Credential)

        Retrieves reboot logs with specific credentials.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01" -StartTime (Get-Date).AddDays(-7)

        Retrieves reboot logs from the last 7 days.

    .EXAMPLE
        "SERVER01", "SERVER02" | Get-RemoteRebootLog

        Retrieves reboot logs from multiple servers via pipeline.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MaxEvents = 50,

        [Parameter()]
        [datetime]$StartTime = (Get-Date).AddDays(-30)
    )

    begin
    {
        Write-Verbose "Début de la recherche des logs de reboot"

        # Event IDs for reboots:
        # 1074 = Shutdown initiated by a user or application
        # 6006 = Event Log service stopped (clean shutdown)
        # 6008 = Unexpected shutdown (crash, power loss)
        # 1076 = Shutdown reason (usually follows 1074)
        $eventIDs = @(1074, 6006, 6008, 1076)
    }

    process
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                Write-Verbose "Connexion à $computer..."

                # Parameters for Get-WinEvent
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

                # Retrieve events
                $events = Get-WinEvent @getWinEventParams

                if ($events)
                {
                    Write-Verbose "Trouvé $($events.Count) événement(s) de reboot sur $computer"

                    # Process and display events
                    $rebootLogs = foreach ($rebootEvent in $events)
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
                                # Shutdown initiated by user/application
                                $properties.Type = 'Initiated Shutdown/Restart'

                                # Extract information from XML message
                                $xml = [xml]$rebootEvent.ToXml()
                                $eventData = $xml.Event.EventData.Data

                                if ($eventData)
                                {
                                    $properties.User = [string]$eventData[6]  # User who initiated
                                    $properties.Process = [string]$eventData[0]  # Process
                                    $properties.Reason = [string]$eventData[2]  # Reason code
                                    $properties.Comment = [string]$eventData[5]  # Comment

                                    # Translate shutdown type
                                    $shutdownType = [string]$eventData[4]
                                    if ($shutdownType -eq 'restart')
                                    {
                                        $properties.Type = 'Restart'
                                    }
                                    elseif ($shutdownType -eq 'power off')
                                    {
                                        $properties.Type = 'Shutdown'
                                    }
                                }
                            }

                            6006
                            {
                                # Event Log service stopped (clean shutdown)
                                $properties.Type = 'Shutdown propre'
                                $properties.Reason = 'Service Event Log arrêté'
                            }

                            6008
                            {
                                # Unexpected shutdown
                                $properties.Type = 'Shutdown imprévu'
                                $properties.Reason = 'Arrêt inattendu du système (crash/panne)'

                                # Try to extract last boot time
                                if ($rebootEvent.Properties)
                                {
                                    $properties.Comment = "Dernière heure de boot connue: $($rebootEvent.Properties[0].Value) $($rebootEvent.Properties[1].Value)"
                                }
                            }

                            1076
                            {
                                # Shutdown reason (additional information)
                                $properties.Type = 'Information raison shutdown'

                                $xml = [xml]$rebootEvent.ToXml()
                                $eventData = $xml.Event.EventData.Data

                                if ($eventData)
                                {
                                    $properties.User = [string]$eventData[3]
                                    $properties.Reason = [string]$eventData[4]
                                    $properties.Comment = [string]$eventData[5]
                                }
                            }
                        }

                        [PSCustomObject]$properties
                    }

                    # Return the objects for manipulation
                    Write-Output $rebootLogs

                }
                else
                {
                    Write-Verbose "Aucun événement de reboot trouvé sur $computer depuis $StartTime"
                }

            }
            catch [System.Exception]
            {
                if ($_.Exception.Message -like "*No events were found*")
                {
                    Write-Verbose "Aucun événement de reboot trouvé sur $computer depuis $StartTime"
                }
                elseif ($_.Exception.Message -like "*The RPC server is unavailable*")
                {
                    Write-Error "Impossible de se connecter à $computer. Vérifiez que le serveur est accessible et que le firewall autorise WinRM/RPC."
                }
                elseif ($_.Exception.Message -like "*Access is denied*")
                {
                    Write-Error "Accès refusé à $computer. Vérifiez vos permissions."
                }
                else
                {
                    Write-Error "Erreur lors de la récupération des événements depuis $computer : $($_.Exception.Message)"
                }
            }
        }
    }

    end
    {
        Write-Verbose "Fin de la recherche des logs de reboot"
    }
}
