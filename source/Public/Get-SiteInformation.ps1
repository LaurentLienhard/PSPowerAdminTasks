function Get-SiteInformation {
    <#
    .SYNOPSIS
        Retrieves Active Directory Sites and Services information and returns SITE class objects.

    .DESCRIPTION
        This function queries Active Directory Sites and Services to retrieve comprehensive information
        about all AD sites or specific sites. The output is returned as an array of SITE class objects,
        making it ideal for auditing AD site topology.

        The function retrieves:
        - Site name, description, and location
        - Associated subnets
        - Site links
        - Creation and modification timestamps
        - Distinguished names

    .PARAMETER Name
        Specifies the name of one or more AD sites to retrieve.
        Supports wildcards (*).
        If not specified, all sites are returned.

    .PARAMETER Server
        Specifies the Active Directory Domain Controller to query.
        If not specified, the function will query the default domain controller.

    .PARAMETER Credential
        A PSCredential object to authenticate to Active Directory.
        If omitted, the current user's credentials will be used.

    .EXAMPLE
        Get-SiteInformation

        Retrieves all AD sites and returns them as SITE objects.

    .EXAMPLE
        Get-SiteInformation -Name "Default-First-Site-Name"

        Retrieves information for the specified site.

    .EXAMPLE
        Get-SiteInformation -Name "Site-*"

        Retrieves all sites whose name starts with "Site-".

    .EXAMPLE
        Get-SiteInformation -Server "DC01.contoso.com" -Credential (Get-Credential)

        Retrieves all sites from a specific domain controller using alternative credentials.

    .EXAMPLE
        $sites = Get-SiteInformation
        $sites | Where-Object { $_.Subnets.Count -eq 0 } | Select-Object Name, Description

        Gets all sites and filters those without any subnets assigned (potential configuration issue).

    .EXAMPLE
        Get-SiteInformation | Export-Csv -Path "C:\Audit\ADSites.csv" -NoTypeInformation

        Exports all site information to a CSV file for auditing purposes.

    .OUTPUTS
        SITE[]
        Returns an array of SITE class objects.

    .NOTES
        Requires the ActiveDirectory PowerShell module.
        Requires appropriate permissions to read Active Directory Sites and Services.
    #>

    [CmdletBinding()]
    [OutputType([SITE[]])]
    param (
        [Parameter(Mandatory = $false,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true,
                   Position = 0)]
        [SupportsWildcards()]
        [string[]]$Name = "*",

        [Parameter(Mandatory = $false)]
        [string]$Server,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN {
        # Verify ActiveDirectory module is available
        $script:moduleAvailable = $true

        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            $errorMessage = "The ActiveDirectory PowerShell module is required but not installed. Install RSAT tools to continue."
            Write-Error -Message $errorMessage -Category NotInstalled
            $script:moduleAvailable = $false
        }

        # Import the module if not already loaded
        if ($script:moduleAvailable -and -not (Get-Module -Name ActiveDirectory)) {
            try {
                Import-Module -Name ActiveDirectory -ErrorAction Stop
                Write-Verbose "ActiveDirectory module imported successfully."
            } catch {
                Write-Error "Failed to import ActiveDirectory module: $($_.Exception.Message)"
                $script:moduleAvailable = $false
            }
        }

        # Build common parameters for AD cmdlets
        $adParams = @{
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('Server')) {
            $adParams['Server'] = $Server
        }

        if ($PSBoundParameters.ContainsKey('Credential')) {
            $adParams['Credential'] = $Credential
        }

        # Collection to store all SITE objects
        $siteCollection = [System.Collections.Generic.List[SITE]]::new()

        Write-Verbose "Starting AD Sites query..."
    }

    PROCESS {
        # Skip processing if module is not available
        if (-not $script:moduleAvailable) {
            return
        }

        foreach ($siteName in $Name) {
            try {
                Write-Verbose "Querying sites with filter: $siteName"

                # Query AD Replication Sites
                $filter = "Name -like '$siteName'"
                $adSites = Get-ADReplicationSite -Filter $filter @adParams -Properties Description, Location, siteObjectBL, WhenCreated, WhenChanged

                if ($null -eq $adSites) {
                    Write-Warning "No sites found matching: $siteName"
                    continue
                }

                foreach ($adSite in $adSites) {
                    Write-Verbose "Processing site: $($adSite.Name)"

                    # Create SITE object from AD object using the static method
                    $siteObject = [SITE]::FromADObject($adSite)

                    # Query site links for this site
                    try {
                        $siteLinks = Get-ADReplicationSiteLink -Filter "SiteList -eq '$($adSite.DistinguishedName)'" @adParams -ErrorAction SilentlyContinue

                        if ($siteLinks) {
                            foreach ($link in $siteLinks) {
                                $siteObject.AddSiteLink($link.Name)
                            }
                            Write-Verbose "Added $($siteLinks.Count) site link(s) to site: $($adSite.Name)"
                        }
                    } catch {
                        Write-Warning "Could not retrieve site links for site $($adSite.Name): $($_.Exception.Message)"
                    }

                    # Add to collection
                    $siteCollection.Add($siteObject)
                    Write-Verbose "Site '$($adSite.Name)' added to collection."
                }

            } catch {
                Write-Error "Failed to retrieve site information for '$siteName': $($_.Exception.Message)"
            }
        }
    }

    END {
        Write-Verbose "Query complete. Returning $($siteCollection.Count) site(s)."

        # Return the collection as an array
        if ($null -ne $siteCollection) {
            return $siteCollection.ToArray()
        }
    }
}
