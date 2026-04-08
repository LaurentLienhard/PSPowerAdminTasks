function Get-ADDomainNTPConfiguration {
    <#
    .SYNOPSIS
        Retrieves NTP configuration from all Domain Controllers in the domain.
    .DESCRIPTION
        This function connects to a specific AD server to list all DCs, then uses WinRM
        to query the w32time service status and registry configuration on each node.
    .PARAMETER ADServer
        The FQDN or IP of a functional Domain Controller to query the AD list from.
    .PARAMETER Credential
        Domain Administrator credentials used for both AD queries and remote execution.
    .EXAMPLE
        $myCreds = Get-Credential
        Get-ADDomainNTPConfiguration -ADServer "caw1pdc03" -Credential $myCreds -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ADServer,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )

    process {
        try {
            Write-Verbose "Authenticating against $ADServer..."

            $DCList = Get-ADDomainController -Filter * -Server $ADServer -Credential $Credential |
                      Select-Object -ExpandProperty HostName

            if (-not $DCList) {
                throw "Could not retrieve Domain Controllers list."
            }

            Write-Verbose "Found $($DCList.Count) servers. Querying NTP configuration..."

            $Results = Invoke-Command -ComputerName $DCList -Credential $Credential -ErrorAction SilentlyContinue -ScriptBlock {
                try {
                    $reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -ErrorAction Stop
                    $status = w32tm /query /status

                    $sourceMatch = $status | Select-String "Source:"
                    $source = if ($sourceMatch) { $sourceMatch.ToString().Split(":")[1].Trim() } else { "N/A" }

                    return [PSCustomObject]@{
                        DCName     = $env:COMPUTERNAME
                        NTPSource  = $source
                        ConfigType = $reg.Type
                        Service    = (Get-Service w32time).Status
                        Accessible = $true
                    }
                }
                catch {
                    return [PSCustomObject]@{
                        DCName     = $env:COMPUTERNAME
                        NTPSource  = "Read Error"
                        ConfigType = "N/A"
                        Service    = "N/A"
                        Accessible = $false
                    }
                }
            }

            if ($Results) {
                return $Results | Select-Object DCName, NTPSource, ConfigType, Service | Sort-Object DCName
            } else {
                Write-Verbose "No WinRM response received from any server."
            }
        }
        catch {
            Write-Error "Error: $($_.Exception.Message)"
        }
    }
}
