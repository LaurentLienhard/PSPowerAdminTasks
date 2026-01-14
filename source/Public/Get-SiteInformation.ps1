function Get-SiteInformation
{
    [CmdletBinding()]
    [OutputType([SITE[]])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [SupportsWildcards()]
        [string[]]$Name = "*",

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        # Check module
        if (-not (Get-Module -Name ActiveDirectory))
        {
            Import-Module ActiveDirectory -ErrorAction Stop
        }

        $adParams = @{ ErrorAction = 'Stop' }
        if ($Server)
        {
            $adParams['Server'] = $Server
        }
        if ($Credential)
        {
            $adParams['Credential'] = $Credential
        }

        $siteCollection = [System.Collections.Generic.List[SITE]]::new()

        # --- NEW: PRE-FETCH ALL DOMAIN CONTROLLERS ---
        Write-Verbose "Pre-fetching all Domain Controllers..."
        $DCTable = @{} # Hashtable for fast lookup: Key=SiteName, Value=List of DCs
        try
        {
            $AllDCs = Get-ADDomainController -Filter * @adParams
            foreach ($dc in $AllDCs)
            {
                if (-not $DCTable.ContainsKey($dc.Site))
                {
                    $DCTable[$dc.Site] = [System.Collections.Generic.List[string]]::new()
                }
                $DCTable[$dc.Site].Add($dc.HostName)
            }
        }
        catch
        {
            Write-Warning "Could not retrieve Domain Controllers: $_"
        }
        # ---------------------------------------------
    }

    PROCESS
    {
        foreach ($siteName in $Name)
        {
            try
            {
                $filter = "Name -like '$siteName'"
                $adSites = Get-ADReplicationSite -Filter $filter @adParams -Properties Description, Location, siteObjectBL, WhenCreated, WhenChanged

                if ($null -eq $adSites)
                {
                    continue
                }

                foreach ($adSite in $adSites)
                {
                    $siteObject = [SITE]::FromADObject($adSite)

                    # --- NEW: MAP DOMAIN CONTROLLERS ---
                    if ($DCTable.ContainsKey($adSite.Name))
                    {
                        foreach ($dcName in $DCTable[$adSite.Name])
                        {
                            $siteObject.AddDomainController($dcName)
                        }
                    }

                    # Add Site Links (Keeping your existing logic logic)
                    try
                    {
                        $siteLinks = Get-ADReplicationSiteLink -Filter "SiteList -eq '$($adSite.DistinguishedName)'" @adParams -Properties Cost, ReplicationFrequencyInMinutes, Description, SiteList
                        if ($siteLinks)
                        {
                            foreach ($link in $siteLinks)
                            {
                                $siteLinkObject = [SITELINK]::FromADObject($link)
                                $siteObject.AddSiteLink($siteLinkObject)
                            }
                        }
                    }
                    catch
                    {
                        Write-Warning "Link error: $_"
                    }

                    $siteCollection.Add($siteObject)
                }
            }
            catch
            {
                Write-Error "Site error: $_"
            }
        }
    }

    END
    {
        if ($null -ne $siteCollection)
        {
            return $siteCollection.ToArray()
        }
    }
}
