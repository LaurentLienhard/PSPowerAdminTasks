class SiteAuditReport
{
    [datetime]$AuditDate
    [System.Collections.Generic.List[SITE]]$AllSites
    [System.Collections.Generic.List[SITE]]$EmptySites        # No Subnets
    [System.Collections.Generic.List[SITE]]$SitesWithoutDCs  # No Domain Controllers <--- NEW
    [System.Collections.Generic.List[string]]$OrphanSubnets

    SiteAuditReport()
    {
        $this.AuditDate = Get-Date
        $this.AllSites = [System.Collections.Generic.List[SITE]]::new()
        $this.EmptySites = [System.Collections.Generic.List[SITE]]::new()
        $this.SitesWithoutDCs = [System.Collections.Generic.List[SITE]]::new() # <--- NEW
        $this.OrphanSubnets = [System.Collections.Generic.List[string]]::new()
    }
}
