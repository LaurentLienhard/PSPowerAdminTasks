function Set-RemoteDnsServer
{
    <#
    .SYNOPSIS
        Configure les serveurs DNS sur un ou plusieurs ordinateurs distants (compatible Server 2008+).
    .DESCRIPTION
        Cette fonction permet soit de remplacer complètement la liste des serveurs DNS, soit de remplacer une adresse DNS spécifique par une nouvelle sur les cartes réseau actives des ordinateurs cibles.
        Elle détecte automatiquement la méthode à utiliser (moderne ou WMI) en fonction du système d'exploitation distant.
    .PARAMETER ComputerName
        Le nom ou une liste de noms d'ordinateurs à cibler.
    .PARAMETER ServerAddresses
        (Jeu de paramètres 'All') Une ou plusieurs adresses IP de serveurs DNS pour remplacer la configuration existante.
    .PARAMETER OldAddress
        (Jeu de paramètres 'Replace') L'adresse IP du serveur DNS à remplacer.
    .PARAMETER NewAddress
        (Jeu de paramètres 'Replace') La nouvelle adresse IP du serveur DNS qui remplacera l'ancienne.
    .PARAMETER Credential
        Spécifie les informations d'identification à utiliser pour se connecter aux ordinateurs distants.
    .EXAMPLE
        # Remplace tous les DNS sur PC01 (moderne) et SRV2008 (ancien) par les serveurs de Google.
        Set-RemoteDnsServer -ComputerName "PC01", "SRV2008" -ServerAddresses "8.8.8.8", "8.8.4.4"

    .EXAMPLE
        # Sur SRV2008, remplace l'ancien DNS 192.168.1.1 par le nouveau 1.1.1.1.
        Set-RemoteDnsServer -ComputerName "SRV2008" -OldAddress "192.168.1.1" -NewAddress "1.1.1.1"
    #>
    [CmdletBinding(DefaultParameterSetName = "All")]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [string[]]$ServerAddresses,

        [Parameter(Mandatory = $true, ParameterSetName = "Replace")]
        [string]$OldAddress,

        [Parameter(Mandatory = $true, ParameterSetName = "Replace")]
        [string]$NewAddress,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    # Traiter chaque ordinateur fourni
    foreach ($computer in $ComputerName)
    {
        Write-Verbose "Tentative de connexion à $computer..."
        $Parameters = @{}
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $Parameters['Credential'] = $Credential
        }

        try
        {
            # Le ScriptBlock contient maintenant les deux logiques (moderne et ancienne)
            $ScriptBlock = {
                # $using: permet d'utiliser les variables locales dans la session distante

                # Détecte si les cmdlets modernes (NetAdapter) sont disponibles
                $modernCmdletsAvailable = Get-Command -Name 'Get-NetAdapter' -ErrorAction SilentlyContinue

                if ($modernCmdletsAvailable)
                {
                    Write-Verbose "[$($env:COMPUTERNAME)] Méthode moderne (NetAdapter) détectée."
                    # ===================================================
                    # LOGIQUE MODERNE (Windows 8 / Server 2012 et plus)
                    # ===================================================
                    $interfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                    if (-not $interfaces)
                    {
                        Write-Warning "[$($env:COMPUTERNAME)] Aucune carte réseau active trouvée."
                        return
                    }

                    switch ($using:PSCmdlet.ParameterSetName)
                    {
                        "All"
                        {
                            foreach ($interface in $interfaces)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] Définition des DNS sur l'interface '$($interface.Name)'..."
                                $interface | Set-DnsClientServerAddress -ServerAddresses $using:ServerAddresses -ErrorAction Stop
                            }
                        }
                        "Replace"
                        {
                            foreach ($interface in $interfaces)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] Traitement de l'interface '$($interface.Name)'..."
                                $currentDnsServers = (Get-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -AddressFamily IPv4).ServerAddresses

                                if ($currentDnsServers -contains $using:OldAddress)
                                {
                                    $newDnsServers = $currentDnsServers | ForEach-Object { if ($_ -eq $using:OldAddress) { $using:NewAddress } else { $_ } }
                                    Write-Verbose "[$($env:COMPUTERNAME)] Remplacement de '$($using:OldAddress)' par '$($using:NewAddress)'. Nouvelle liste : $($newDnsServers -join ', ')"
                                    $interface | Set-DnsClientServerAddress -ServerAddresses $newDnsServers -ErrorAction Stop
                                }
                                else
                                {
                                    Write-Warning "[$($env:COMPUTERNAME)] L'adresse '$($using:OldAddress)' n'a pas été trouvée sur l'interface '$($interface.Name)'."
                                }
                            }
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$($env:COMPUTERNAME)] Méthode WMI (ancienne) utilisée."
                    # ===================================================
                    # LOGIQUE ANCIENNE (WMI pour Windows 7 / Server 2008)
                    # ===================================================
                    # On filtre sur les cartes qui ont une configuration IP active
                    $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
                    if (-not $adapters)
                    {
                        Write-Warning "[$($env:COMPUTERNAME)] Aucune carte réseau avec IP activée trouvée via WMI."
                        return
                    }

                    switch ($using:PSCmdlet.ParameterSetName)
                    {
                        "All"
                        {
                            foreach ($adapter in $adapters)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Définition des DNS sur l'interface '$($adapter.Description)'..."
                                $result = $adapter.SetDNSServerSearchOrder($using:ServerAddresses)
                                if ($result.ReturnValue -ne 0) { Write-Warning "Une erreur WMI est survenue (Code: $($result.ReturnValue))" }
                            }
                        }
                        "Replace"
                        {
                            foreach ($adapter in $adapters)
                            {
                                Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Traitement de l'interface '$($adapter.Description)'..."
                                $currentDnsServers = $adapter.DNSServerSearchOrder

                                if ($currentDnsServers -contains $using:OldAddress)
                                {
                                    $newDnsServers = $currentDnsServers | ForEach-Object { if ($_ -eq $using:OldAddress) { $using:NewAddress } else { $_ } }
                                    Write-Verbose "[$($env:COMPUTERNAME)] [WMI] Remplacement de '$($using:OldAddress)' par '$($using:NewAddress)'. Nouvelle liste : $($newDnsServers -join ', ')"
                                    $result = $adapter.SetDNSServerSearchOrder($newDnsServers)
                                    if ($result.ReturnValue -ne 0) { Write-Warning "Une erreur WMI est survenue (Code: $($result.ReturnValue))" }
                                }
                                else
                                {
                                    Write-Warning "[$($env:COMPUTERNAME)] [WMI] L'adresse '$($using:OldAddress)' n'a pas été trouvée sur l'interface '$($adapter.Description)'."
                                }
                            }
                        }
                    }
                }
            }

            Invoke-Command -ComputerName $computer @Parameters -ErrorAction Stop -ScriptBlock $ScriptBlock
            Write-Verbose "Opération DNS terminée avec succès sur $computer."
        }
        catch
        {
            Write-Warning "Échec de la mise à jour DNS sur $computer. Erreur: $($_.Exception.Message)"
        }
    }
}
