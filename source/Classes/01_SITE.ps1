class SITE {
    # Properties representing Active Directory Site information
    [string]$Name
    [string]$Description
    [string]$Location
    [string]$DistinguishedName
    [System.Collections.ArrayList]$Subnets
    [System.Collections.ArrayList]$SiteLinks
    [datetime]$WhenCreated
    [datetime]$WhenChanged
    [hashtable]$Options

    # Default constructor
    SITE() {
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
        $this.Options = @{}
    }

    # Constructor with name
    SITE([string]$Name) {
        $this.Name = $Name
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
        $this.Options = @{}
    }

    # Full constructor
    SITE([string]$Name, [string]$Description, [string]$Location) {
        $this.Name = $Name
        $this.Description = $Description
        $this.Location = $Location
        $this.Subnets = [System.Collections.ArrayList]::new()
        $this.SiteLinks = [System.Collections.ArrayList]::new()
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
    [void] AddSiteLink([string]$SiteLink) {
        if (-not $this.SiteLinks.Contains($SiteLink)) {
            [void]$this.SiteLinks.Add($SiteLink)
        }
    }

    # Method to remove a site link
    [bool] RemoveSiteLink([string]$SiteLink) {
        if ($this.SiteLinks.Contains($SiteLink)) {
            $this.SiteLinks.Remove($SiteLink)
            return $true
        }
        return $false
    }

    # Method to convert to hashtable
    [hashtable] ToHashtable() {
        return @{
            Name               = $this.Name
            Description        = $this.Description
            Location           = $this.Location
            DistinguishedName  = $this.DistinguishedName
            Subnets           = $this.Subnets
            SiteLinks         = $this.SiteLinks
            WhenCreated       = $this.WhenCreated
            WhenChanged       = $this.WhenChanged
            Options           = $this.Options
        }
    }

    # Method to display site information
    [string] ToString() {
        $subnetCount = $this.Subnets.Count
        $linkCount = $this.SiteLinks.Count
        return "Site: $($this.Name) | Subnets: $subnetCount | SiteLinks: $linkCount"
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
