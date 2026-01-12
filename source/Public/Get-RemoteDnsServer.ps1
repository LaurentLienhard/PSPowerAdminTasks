function Get-RemoteDnsServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    # 1. Initialisation de la liste AVANT le traitement
    Begin
    {
        # On utilise une liste générique pour la performance (plus rapide que += sur un tableau)
        $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    }

    # 2. Traitement de chaque élément (accumulation)
    Process
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose "Processing $computer via COMPUTER class..."
            try
            {
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $srvObject = [COMPUTER]::new($computer, $Credential)
                }
                else {
                    $srvObject = [COMPUTER]::new($computer)
                }

                $srvObject.GetDnsConfig()

                # Création de l'objet résultat
                $resultObj = [PSCustomObject]@{
                    ComputerName = $srvObject.Name
                    DNSServers   = $srvObject.DnsServers
                    Status       = $srvObject.Status
                    CheckedAt    = $srvObject.CheckTime
                }

                # AJOUT à la liste (pas d'affichage ici)
                $AllResults.Add($resultObj)
            }
            catch
            {
                Write-Warning "Fatal error processing $computer : $($_.Exception.Message)"
            }
        }
    }

    # 3. Restitution du résultat unique À LA FIN
    End
    {
        return $AllResults
    }
}
