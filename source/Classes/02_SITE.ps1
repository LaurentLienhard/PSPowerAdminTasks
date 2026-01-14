class SITE
{
    # Properties
    [string]$Name
    [string]$Description
    [string]$Location
    [string]$DistinguishedName
    [System.Collections.Generic.List[string]]$Subnets
    [System.Collections.Generic.List[SITELINK]]$SiteLinks
    [System.Collections.Generic.List[string]]$DomainControllers
    [int]$TotalInterSiteCost

    # CORRECTION : Syntaxe compatible PowerShell 5.1
    [Nullable[datetime]]$WhenCreated
    [Nullable[datetime]]$WhenChanged

    [hashtable]$Options

    # Default constructor
    SITE()
    {
        $this.Subnets = [System.Collections.Generic.List[string]]::new()
        $this.SiteLinks = [System.Collections.Generic.List[SITELINK]]::new()
        $this.DomainControllers = [System.Collections.Generic.List[string]]::new()
        $this.TotalInterSiteCost = 0
        $this.Options = @{}
    }

    # Method to add a subnet
    [void] AddSubnet([string]$Subnet)
    {
        if (-not $this.Subnets.Contains($Subnet))
        {
            [void]$this.Subnets.Add($Subnet)
        }
    }

    # Method to add a Site Link
    [void] AddSiteLink([SITELINK]$SiteLink)
    {
        if ($null -ne $SiteLink)
        {
            $this.SiteLinks.Add($SiteLink)
            $this.UpdateTotalInterSiteCost()
        }
    }

    # Method to add a Domain Controller
    [void] AddDomainController([string]$DCName)
    {
        if (-not $this.DomainControllers.Contains($DCName))
        {
            $this.DomainControllers.Add($DCName)
        }
    }

    # Update Cost
    [void] UpdateTotalInterSiteCost()
    {
        $this.TotalInterSiteCost = ($this.SiteLinks | Measure-Object -Property Cost -Sum).Sum
    }

    # Static method to create from AD object
    static [SITE] FromADObject([PSObject]$ADObject)
    {
        $site = [SITE]::new()
        $site.Name = $ADObject.Name
        $site.Description = $ADObject.Description
        $site.Location = $ADObject.Location
        $site.DistinguishedName = $ADObject.DistinguishedName

        # Affectation sécurisée
        $site.WhenCreated = $ADObject.WhenCreated
        $site.WhenChanged = $ADObject.WhenChanged

        if ($ADObject.siteObjectBL)
        {
            foreach ($subnet in $ADObject.siteObjectBL)
            {
                $site.AddSubnet($subnet)
            }
        }
        return $site
    }
}
