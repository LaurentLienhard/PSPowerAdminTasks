function Get-RemoteRebootLog {
    <#
    .SYNOPSIS
        Récupère les logs de reboot d'un serveur distant.

    .DESCRIPTION
        Cette fonction interroge le journal d'événements System d'un serveur distant pour
        identifier les événements de reboot (ID 1074, 6006, 6008) et affiche qui a
        initié le reboot ainsi que la raison si elle est disponible.

    .PARAMETER ComputerName
        Nom ou adresse IP du serveur à interroger.

    .PARAMETER Credential
        Informations d'identification pour se connecter au serveur distant.
        Si non spécifié, utilise les credentials de l'utilisateur actuel.

    .PARAMETER MaxEvents
        Nombre maximum d'événements à récupérer. Par défaut: 50.

    .PARAMETER StartTime
        Date de début pour la recherche des événements. Par défaut: 30 jours en arrière.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01"

        Récupère les logs de reboot du serveur SERVER01.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01" -Credential (Get-Credential)

        Récupère les logs de reboot avec des credentials spécifiques.

    .EXAMPLE
        Get-RemoteRebootLog -ComputerName "SERVER01" -StartTime (Get-Date).AddDays(-7)

        Récupère les logs de reboot des 7 derniers jours.

    .EXAMPLE
        "SERVER01", "SERVER02" | Get-RemoteRebootLog

        Récupère les logs de reboot de plusieurs serveurs via pipeline.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$MaxEvents = 50,

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime = (Get-Date).AddDays(-30)
    )

    begin {
        Write-Verbose "Début de la recherche des logs de reboot"

        # Event IDs pour les reboots:
        # 1074 = Shutdown initié par un utilisateur ou une application
        # 6006 = Event Log service stopped (shutdown propre)
        # 6008 = Shutdown imprévu (crash, perte de courant)
        # 1076 = Raison du shutdown (suit généralement 1074)
        $eventIDs = @(1074, 6006, 6008, 1076)
    }

    process {
        foreach ($computer in $ComputerName) {
            try {
                Write-Verbose "Connexion à $computer..."

                # Paramètres pour Get-WinEvent
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

                if ($Credential) {
                    $getWinEventParams.Add('Credential', $Credential)
                }

                # Récupération des événements
                $events = Get-WinEvent @getWinEventParams

            if ($events) {
                Write-Verbose "Trouvé $($events.Count) événement(s) de reboot sur $computer"

                # Traitement et affichage des événements
                $rebootLogs = foreach ($event in $events) {
                    $properties = @{
                        TimeCreated = $event.TimeCreated
                        EventID     = $event.Id
                        Computer    = $event.MachineName
                        User        = 'N/A'
                        Reason      = 'N/A'
                        Process     = 'N/A'
                        Comment     = 'N/A'
                        Type        = 'N/A'
                    }

                    switch ($event.Id) {
                        1074 {
                            # Shutdown initié par utilisateur/application
                            $properties.Type = 'Shutdown/Restart initié'

                            # Extraction des informations du message XML
                            $xml = [xml]$event.ToXml()
                            $eventData = $xml.Event.EventData.Data

                            if ($eventData) {
                                $properties.User = [string]$eventData[6]  # User qui a initié
                                $properties.Process = [string]$eventData[0]  # Processus
                                $properties.Reason = [string]$eventData[2]  # Code raison
                                $properties.Comment = [string]$eventData[5]  # Commentaire

                                # Traduction du type de shutdown
                                $shutdownType = [string]$eventData[4]
                                if ($shutdownType -eq 'restart') {
                                    $properties.Type = 'Restart'
                                } elseif ($shutdownType -eq 'power off') {
                                    $properties.Type = 'Shutdown'
                                }
                            }
                        }

                        6006 {
                            # Event Log service arrêté (shutdown propre)
                            $properties.Type = 'Shutdown propre'
                            $properties.Reason = 'Service Event Log arrêté'
                        }

                        6008 {
                            # Shutdown imprévu
                            $properties.Type = 'Shutdown imprévu'
                            $properties.Reason = 'Arrêt inattendu du système (crash/panne)'

                            # Tente d'extraire l'heure du dernier boot
                            if ($event.Properties) {
                                $properties.Comment = "Dernière heure de boot connue: $($event.Properties[0].Value) $($event.Properties[1].Value)"
                            }
                        }

                        1076 {
                            # Raison du shutdown (information supplémentaire)
                            $properties.Type = 'Information raison shutdown'

                            $xml = [xml]$event.ToXml()
                            $eventData = $xml.Event.EventData.Data

                            if ($eventData) {
                                $properties.User = [string]$eventData[3]
                                $properties.Reason = [string]$eventData[4]
                                $properties.Comment = [string]$eventData[5]
                            }
                        }
                    }

                    [PSCustomObject]$properties
                }

                # Retourne les objets pour pouvoir les manipuler
                Write-Output $rebootLogs

            } else {
                Write-Verbose "Aucun événement de reboot trouvé sur $computer depuis le $StartTime"
            }

            } catch [System.Exception] {
                if ($_.Exception.Message -like "*No events were found*") {
                    Write-Verbose "Aucun événement de reboot trouvé sur $computer depuis le $StartTime"
                } elseif ($_.Exception.Message -like "*The RPC server is unavailable*") {
                    Write-Error "Impossible de se connecter à $computer. Vérifiez que le serveur est accessible et que le pare-feu autorise WinRM/RPC."
                } elseif ($_.Exception.Message -like "*Access is denied*") {
                    Write-Error "Accès refusé à $computer. Vérifiez vos permissions."
                } else {
                    Write-Error "Erreur lors de la récupération des événements de $computer : $($_.Exception.Message)"
                }
            }
        }
    }

    end {
        Write-Verbose "Fin de la recherche des logs de reboot"
    }
}
