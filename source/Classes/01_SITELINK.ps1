class SITELINK {
    # Properties representing Active Directory Site Link information
    [string]$Name
    [string]$Description
    [int]$Cost
    [int]$ReplicationFrequency
    [bool]$ReplaceWithInterSiteTopology
    [System.Collections.Generic.List[string]]$Sites
    [datetime]$WhenCreated
    [datetime]$WhenChanged
    [hashtable]$Options

    # Default constructor
    SITELINK() {
        $this.Sites = [System.Collections.Generic.List[string]]::new()
        $this.Options = @{}
        $this.Cost = 100  # Default cost in AD
        $this.ReplicationFrequency = 180  # Default frequency in minutes
        $this.ReplaceWithInterSiteTopology = $false
    }

    # Constructor with name
    SITELINK([string]$Name) {
        $this.Name = $Name
        $this.Sites = [System.Collections.Generic.List[string]]::new()
        $this.Options = @{}
        $this.Cost = 100
        $this.ReplicationFrequency = 180
        $this.ReplaceWithInterSiteTopology = $false
    }

    # Full constructor
    SITELINK([string]$Name, [int]$Cost, [int]$ReplicationFrequency) {
        $this.Name = $Name
        $this.Cost = $Cost
        $this.ReplicationFrequency = $ReplicationFrequency
        $this.Sites = [System.Collections.Generic.List[string]]::new()
        $this.Options = @{}
        $this.ReplaceWithInterSiteTopology = $false
    }

    # Method to add a site to the link
    [void] AddSite([string]$Site) {
        if (-not $this.Sites.Contains($Site)) {
            [void]$this.Sites.Add($Site)
        }
    }

    # Method to remove a site from the link
    [bool] RemoveSite([string]$Site) {
        if ($this.Sites.Contains($Site)) {
            $this.Sites.Remove($Site)
            return $true
        }
        return $false
    }

    # Method to convert to hashtable
    [hashtable] ToHashtable() {
        return @{
            Name                            = $this.Name
            Description                     = $this.Description
            Cost                           = $this.Cost
            ReplicationFrequency           = $this.ReplicationFrequency
            ReplaceWithInterSiteTopology   = $this.ReplaceWithInterSiteTopology
            Sites                          = $this.Sites
            WhenCreated                    = $this.WhenCreated
            WhenChanged                    = $this.WhenChanged
            Options                        = $this.Options
        }
    }

    # Method to display site link information
    [string] ToString() {
        $siteCount = $this.Sites.Count
        return "SiteLink: $($this.Name) | Cost: $($this.Cost) | Frequency: $($this.ReplicationFrequency)min | Sites: $siteCount"
    }

    # Static method to create from AD object
    static [SITELINK] FromADObject([PSObject]$ADObject) {
        $siteLink = [SITELINK]::new()
        $siteLink.Name = $ADObject.Name
        $siteLink.Description = $ADObject.Description
        $siteLink.Cost = $ADObject.Cost
        $siteLink.ReplicationFrequency = $ADObject.ReplicationFrequencyInMinutes
        $siteLink.ReplaceWithInterSiteTopology = $ADObject.ReplaceWithInterSiteTopology
        $siteLink.WhenCreated = $ADObject.WhenCreated
        $siteLink.WhenChanged = $ADObject.WhenChanged

        # Add sites from SiteList
        if ($ADObject.SiteList) {
            foreach ($site in $ADObject.SiteList) {
                # Extract site name from DN (e.g., CN=Site-Name,CN=Sites,CN=Configuration,...)
                $siteName = $site -replace '^CN=([^,]+),.+$', '$1'
                $siteLink.AddSite($siteName)
            }
        }

        return $siteLink
    }
}
