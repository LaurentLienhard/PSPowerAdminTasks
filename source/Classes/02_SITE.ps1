class SITE {
    # Properties representing Active Directory Site information
    [string]$Name
    [string]$Description
    [string]$Location
    [string]$DistinguishedName
    [System.Collections.ArrayList]$Subnets
    [System.Collections.ArrayList]$SiteLinks
    [int]$TotalInterSiteCost
    [datetime]$WhenCreated
    [datetime]$WhenChanged
    [hashtable]$Options

    # Default constructor
    SITE() {
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
        $this.TotalInterSiteCost = 0
        $this.Options = @{}
    }

    # Constructor with name
    SITE([string]$Name) {
        $this.Name = $Name
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
        $this.TotalInterSiteCost = 0
        $this.Options = @{}
    }

    # Full constructor
    SITE([string]$Name, [string]$Description, [string]$Location) {
        $this.Name = $Name
        $this.Description = $Description
        $this.Location = $Location
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
        $this.TotalInterSiteCost = 0
        $this.Options = @{}
    }

    # Method to add a subnet to the site
    [void] AddSubnet([string]$Subnet) {
        if (-not $this.Subnets.Contains($Subnet)) {
            [void]$this.Subnets.Add($Subnet)
        }
    }

    # Method to remove a subnet from the site
    [bool] RemoveSubnet([string]$Subnet) {
        if ($this.Subnets.Contains($Subnet)) {
            $this.Subnets.Remove($Subnet)
            return $true
        }
        return $false
    }

    # Method to add a site link
    [void] AddSiteLink([SITELINK]$SiteLink) {
        if ($SiteLink -and -not ($this.SiteLinks | Where-Object { $_.Name -eq $SiteLink.Name })) {
            [void]$this.SiteLinks.Add($SiteLink)
            $this.UpdateTotalInterSiteCost()
        }
    }

    # Method to remove a site link
    [bool] RemoveSiteLink([string]$SiteLinkName) {
        $linkToRemove = $this.SiteLinks | Where-Object { $_.Name -eq $SiteLinkName }
        if ($linkToRemove) {
            $this.SiteLinks.Remove($linkToRemove)
            $this.UpdateTotalInterSiteCost()
            return $true
        }
        return $false
    }

    # Method to update total inter-site cost
    [void] UpdateTotalInterSiteCost() {
        $this.TotalInterSiteCost = ($this.SiteLinks | Measure-Object -Property Cost -Sum).Sum
        if ($null -eq $this.TotalInterSiteCost) {
            $this.TotalInterSiteCost = 0
        }
    }

    # Method to get site links as summary
    [PSCustomObject[]] GetSiteLinksSummary() {
        return $this.SiteLinks | Select-Object -Property Name, Cost, ReplicationFrequency, @{Name = 'Sites'; Expression = { $_.Sites -join ', ' } }
    }

    # Method to convert to hashtable
    [hashtable] ToHashtable() {
        return @{
            Name                   = $this.Name
            Description            = $this.Description
            Location               = $this.Location
            DistinguishedName      = $this.DistinguishedName
            Subnets               = $this.Subnets
            SiteLinks             = $this.SiteLinks
            TotalInterSiteCost    = $this.TotalInterSiteCost
            WhenCreated           = $this.WhenCreated
            WhenChanged           = $this.WhenChanged
            Options               = $this.Options
        }
    }

    # Method to display site information
    [string] ToString() {
        $subnetCount = $this.Subnets.Count
        $linkCount = $this.SiteLinks.Count
        return "Site: $($this.Name) | Subnets: $subnetCount | SiteLinks: $linkCount | Cost: $($this.TotalInterSiteCost)"
    }

    # Static method to create from AD object
    static [SITE] FromADObject([PSObject]$ADObject) {
        $site = [SITE]::new()
        $site.Name = $ADObject.Name
        $site.Description = $ADObject.Description
        $site.Location = $ADObject.Location
        $site.DistinguishedName = $ADObject.DistinguishedName
        $site.WhenCreated = $ADObject.WhenCreated
        $site.WhenChanged = $ADObject.WhenChanged

        if ($ADObject.siteObjectBL) {
            foreach ($subnet in $ADObject.siteObjectBL) {
                $site.AddSubnet($subnet)
            }
        }

        return $site
    }
}
