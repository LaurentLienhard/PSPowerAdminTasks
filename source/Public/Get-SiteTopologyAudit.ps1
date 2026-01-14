function Get-SiteTopologyAudit
{
    [CmdletBinding()]
    [OutputType([SiteAuditReport])]
    param (
        [string]$Server,
        [System.Management.Automation.PSCredential]$Credential
    )

    process
    {
        $Report = [SiteAuditReport]::new()
        $adParams = @{ ErrorAction = 'Stop' }
        if ($Server)
        {
            $adParams['Server'] = $Server
        }
        if ($Credential)
        {
            $adParams['Credential'] = $Credential
        }

        Write-Host "1. Retrieving Sites and Domain Controllers..." -ForegroundColor Cyan

        $Sites = Get-SiteInformation @adParams

        if ($Sites)
        {
            foreach ($siteItem in $Sites)
            {
                if ($siteItem -is [SITE])
                {
                    $Report.AllSites.Add($siteItem)

                    # Check for Subnets
                    if ($siteItem.Subnets.Count -eq 0)
                    {
                        $Report.EmptySites.Add($siteItem)
                    }

                    # Check for Domain Controllers (NEW)
                    if ($siteItem.DomainControllers.Count -eq 0)
                    {
                        $Report.SitesWithoutDCs.Add($siteItem)
                    }
                }
            }
        }

        Write-Host "2. Searching for Orphan Subnets..." -ForegroundColor Cyan
        try
        {
            $OrphanSubnetsAD = Get-ADReplicationSubnet -Filter { siteObject -notlike "*" } @adParams -Properties Name
            if ($OrphanSubnetsAD)
            {
                foreach ($subnet in $OrphanSubnetsAD)
                {
                    $Report.OrphanSubnets.Add($subnet.Name)
                }
            }
        }
        catch
        {
        }

        # --- OUTPUT ---
        Write-Host "`n--- AUDIT RESULTS ---" -ForegroundColor Green
        Write-Host "Total Sites       : $($Report.AllSites.Count)"

        # Color Logic
        $EmptyColor = if ($Report.EmptySites.Count -gt 0)
        {
            "Red"
        }
        else
        {
            "Green"
        }
        Write-Host "Sites (No Subnet) : $($Report.EmptySites.Count)" -ForegroundColor $EmptyColor

        $DCColor = if ($Report.SitesWithoutDCs.Count -gt 0)
        {
            "Yellow"
        }
        else
        {
            "Green"
        } # Yellow because a site without a DC is valid (hub-spoke)
        Write-Host "Sites (No DC)     : $($Report.SitesWithoutDCs.Count)" -ForegroundColor $DCColor

        $OrphanColor = if ($Report.OrphanSubnets.Count -gt 0)
        {
            "Red"
        }
        else
        {
            "Green"
        }
        Write-Host "Orphan Subnets    : $($Report.OrphanSubnets.Count)" -ForegroundColor $OrphanColor
        Write-Host "---------------------`n"

        return $Report
    }
}
