class SITELINK {
    # Properties
    [string]$Name
    [string]$Description
    [int]$Cost
    [int]$ReplicationFrequency
    [bool]$ReplaceWithInterSiteTopology
    [System.Collections.Generic.List[string]]$Sites

    # CORRECTION : Syntaxe compatible PowerShell 5.1
    [Nullable[datetime]]$WhenCreated
    [Nullable[datetime]]$WhenChanged

    [hashtable]$Options

    # Default constructor
    SITELINK() {
        $this.Sites = [System.Collections.Generic.List[string]]::new()
        $this.Options = @{}
        $this.Cost = 100
        $this.ReplicationFrequency = 180
        $this.ReplaceWithInterSiteTopology = $false
    }

    # Method to add a site
    [void] AddSite([string]$Site) {
        if (-not $this.Sites.Contains($Site)) {
            [void]$this.Sites.Add($Site)
        }
    }

    # Static method to create from AD object
    static [SITELINK] FromADObject([PSObject]$ADObject) {
        $siteLink = [SITELINK]::new()
        $siteLink.Name = $ADObject.Name
        $siteLink.Description = $ADObject.Description

        if ($ADObject.Cost) { $siteLink.Cost = $ADObject.Cost }
        if ($ADObject.ReplicationFrequencyInMinutes) { $siteLink.ReplicationFrequency = $ADObject.ReplicationFrequencyInMinutes }

        $siteLink.ReplaceWithInterSiteTopology = [bool]$ADObject.ReplaceWithInterSiteTopology

        $siteLink.WhenCreated = $ADObject.WhenCreated
        $siteLink.WhenChanged = $ADObject.WhenChanged

        if ($ADObject.SiteList) {
            foreach ($site in $ADObject.SiteList) {
                $siteName = $site -replace '^CN=([^,]+),.+$', '$1'
                $siteLink.AddSite($siteName)
            }
        }

        return $siteLink
    }
}
