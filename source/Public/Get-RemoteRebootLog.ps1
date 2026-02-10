function Get-RemoteRebootLog
{
    <#
    .SYNOPSIS
        Retrieves reboot logs from a remote server with readable reason codes.
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

    BEGIN
    {
        Write-Verbose "Début de la recherche des logs de reboot"

        # Event IDs for reboots
        $eventIDs = @(1074, 6006, 6008, 1076)

        # Table de correspondance des codes de raison (Reason Codes)
        # Basé sur les codes standard Windows System Shutdown Reason Codes
        $reasonMap = @{
            '0x00000000' = 'Autre (Non planifié)'
            '0x40000000' = 'Autre (Non planifié)'
            '0x80000000' = 'Autre (Planifié)'
            '0x40010004' = 'Système : Maintenance (Planifié)'
            '0x40000015' = 'OS : Mise à niveau (Planifié)'
            '0x80020002' = 'OS : Récupération (Planifié)'
            '0x80020010' = 'OS : Service pack (Planifié)'
            '0x8003000f' = 'OS : Installation de correctif (Planifié)'
            '0x80030002' = 'OS : Installation de correctif (Planifié)'
            '0x41000000' = 'Problème matériel (Non planifié)'
            '0x00050000' = 'Panne système (Erreur Stop - BSOD)'
            '0x800000ff' = 'Système inactif / Veille'
            '0x00040000' = 'Problème Application (Non planifié)'
            '0x80040002' = 'Application : Installation (Planifié)'
            '0x80040005' = 'Application : Maintenance (Planifié)'
            '0x00020000' = 'Problème Sécurité'
            '0x8002000e' = 'Sécurité : Mise à jour credential (Planifié)'
            '0x20000000' = 'Arrêt via API (Logiciel)'
        }
    }

    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                Write-Verbose "Connexion à $computer..."

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
                    Write-Verbose "Trouvé $($events.Count) événement(s) de reboot sur $computer"

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

                                $xml = [xml]$rebootEvent.ToXml()
                                $eventData = $xml.Event.EventData.Data

                                if ($eventData)
                                {
                                    $properties.User = $eventData[6].InnerText
                                    $properties.Process = $eventData[0].InnerText

                                    # Gestion du code de raison
                                    $rawReason = $eventData[2].InnerText
                                    if ($reasonMap.ContainsKey($rawReason)) {
                                        $properties.Reason = "$rawReason ($($reasonMap[$rawReason]))"
                                    } else {
                                        $properties.Reason = $rawReason
                                    }

                                    $properties.Comment = $eventData[5].InnerText

                                    $shutdownType = $eventData[4].InnerText
                                    if ($shutdownType -eq 'restart') { $properties.Type = 'Restart' }
                                    elseif ($shutdownType -eq 'power off') { $properties.Type = 'Shutdown' }
                                }
                            }

                            6006
                            {
                                $properties.Type = 'Shutdown propre'
                                $properties.Reason = 'Service Event Log arrêté'
                            }

                            6008
                            {
                                $properties.Type = 'Shutdown imprévu'
                                $properties.Reason = 'Arrêt inattendu du système (crash/panne)'

                                if ($rebootEvent.Properties)
                                {
                                    $properties.Comment = "Dernière heure de boot connue: $($rebootEvent.Properties[0].Value) $($rebootEvent.Properties[1].Value)"
                                }
                            }

                            1076
                            {
                                # Shutdown reason (additional info)
                                $properties.Type = 'Information raison shutdown'

                                $xml = [xml]$rebootEvent.ToXml()
                                $eventData = $xml.Event.EventData.Data

                                if ($eventData)
                                {
                                    $properties.User = $eventData[3].InnerText

                                    # Gestion du code de raison
                                    $rawReason = $eventData[4].InnerText
                                    if ($reasonMap.ContainsKey($rawReason)) {
                                        $properties.Reason = "$rawReason ($($reasonMap[$rawReason]))"
                                    } else {
                                        $properties.Reason = $rawReason
                                    }

                                    $properties.Comment = $eventData[5].InnerText
                                }
                            }
                        }

                        [PSCustomObject]$properties
                    }

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
                    Write-Error "Impossible de se connecter à $computer. Vérifiez que le serveur est accessible (Firewall/WinRM)."
                }
                elseif ($_.Exception.Message -like "*Access is denied*")
                {
                    Write-Error "Accès refusé à $computer. Vérifiez vos permissions."
                }
                else
                {
                    Write-Error "Erreur sur $computer : $($_.Exception.Message)"
                }
            }
        }
    }

    END
    {
        Write-Verbose "Reboot log search completed"
    }
}
