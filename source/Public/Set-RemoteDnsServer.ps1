function Set-RemoteDnsServer
{
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

    # 1. Initialisation
    Begin
    {
        $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    }

    # 2. Traitement et accumulation
    Process
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose "Processing $computer via COMPUTER class..."

            # Objet pour le rapport de cette ligne
            $reportItem = $null

            try
            {
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $srvObject = [COMPUTER]::new($computer, $Credential)
                }
                else {
                    $srvObject = [COMPUTER]::new($computer)
                }

                if ($srvObject.Status -ne "Ping OK") {
                    # Si Ping KO, on note l'échec et on passe au suivant
                    $reportItem = [PSCustomObject]@{
                        ComputerName = $computer
                        Action       = "None"
                        Result       = "Unreachable"
                        NewDNS       = $null
                    }
                    $AllResults.Add($reportItem)
                    continue
                }

                switch ($PSCmdlet.ParameterSetName)
                {
                    "All" {
                        $srvObject.SetDnsServers($ServerAddresses)
                        $actionLog = "Set-All"
                    }

                    "Replace" {
                        $srvObject.ModifyDnsServer($OldAddress, $NewAddress)
                        $actionLog = "Replace ($OldAddress -> $NewAddress)"
                    }
                }

                # On crée le rapport de succès
                $reportItem = [PSCustomObject]@{
                    ComputerName = $srvObject.Name
                    Action       = $actionLog
                    Result       = "Success"
                    NewDNS       = $srvObject.DnsServers
                }
            }
            catch
            {
                # On crée le rapport d'erreur
                $reportItem = [PSCustomObject]@{
                    ComputerName = $computer
                    Action       = "Error"
                    Result       = $_.Exception.Message
                    NewDNS       = $null
                }
            }

            # Ajout à la liste globale
            if ($reportItem) { $AllResults.Add($reportItem) }
        }
    }

    # 3. Restitution finale
    End
    {
        return $AllResults
    }
}
