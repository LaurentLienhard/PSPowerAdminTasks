BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module - find the versioned module manifest
    $outputModulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    $versionedManifest = Get-ChildItem -Path $outputModulePath -Include '*.psd1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -match '^\d+\.\d+\.\d+' } |
        Select-Object -First 1

    if ($versionedManifest) {
        $script:module = Import-Module $versionedManifest.FullName -Force -ErrorAction Stop -PassThru
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        if (Test-Path $sourcePath) {
            $script:module = Import-Module $sourcePath -Force -ErrorAction Stop -PassThru
        } else {
            throw "Unable to find module manifest"
        }
    }

    # Helper function to create instances within module scope
    $script:NewSite = {
        param($Name, $Description, $Location)
        if ($PSBoundParameters.Count -eq 0) {
            return [SITE]::new()
        } elseif ($PSBoundParameters.Count -eq 1) {
            return [SITE]::new($Name)
        } else {
            return [SITE]::new($Name, $Description, $Location)
        }
    }

    $script:FromADObject = {
        param($ADObject)
        return [SITE]::FromADObject($ADObject)
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
}

Describe 'SITE Class' -Tag 'Unit', 'Class' {
    Context 'Class Definition' {
        It 'Should have SITE class available' {
            $site = & $script:module $script:NewSite
            $site | Should -Not -BeNullOrEmpty
        }

        It 'Should have Name property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'Name'
        }

        It 'Should have Description property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'Description'
        }

        It 'Should have Location property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'Location'
        }

        It 'Should have DistinguishedName property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'DistinguishedName'
        }

        It 'Should have Subnets property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'Subnets'
        }

        It 'Should have SiteLinks property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'SiteLinks'
        }

        It 'Should have WhenCreated property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'WhenCreated'
        }

        It 'Should have WhenChanged property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'WhenChanged'
        }

        It 'Should have Options property' {
            $site = & $script:module $script:NewSite
            $site.PSObject.Properties.Name | Should -Contain 'Options'
        }
    }

    Context 'Constructors' {
        It 'Should create instance with default constructor' {
            $site = & $script:module $script:NewSite

            $site | Should -Not -BeNullOrEmpty
            # Check properties exist (they may be null/empty after module deserialization)
            $site.PSObject.Properties.Name | Should -Contain 'Subnets'
            $site.PSObject.Properties.Name | Should -Contain 'SiteLinks'
            $site.PSObject.Properties.Name | Should -Contain 'Options'
        }

        It 'Should create instance with name only constructor' {
            $site = & $script:module $script:NewSite 'Paris'

            $site.Name | Should -Be 'Paris'
            $site.Subnets.GetType().Name | Should -Be 'ArrayList'
            $site.SiteLinks.GetType().Name | Should -Be 'ArrayList'
        }

        It 'Should create instance with full constructor' {
            $site = & $script:module $script:NewSite 'Paris' 'Main office' 'Paris, France'

            $site.Name | Should -Be 'Paris'
            $site.Description | Should -Be 'Main office'
            $site.Location | Should -Be 'Paris, France'
            $site.Subnets.GetType().Name | Should -Be 'ArrayList'
            $site.SiteLinks.GetType().Name | Should -Be 'ArrayList'
        }

        It 'Should initialize collections as empty' {
            $site = & $script:module $script:NewSite

            $site.Subnets.Count | Should -Be 0
            $site.SiteLinks.Count | Should -Be 0
            $site.Options.Count | Should -Be 0
        }
    }

    Context 'AddSubnet Method' {
        BeforeEach {
            $script:testSite = & $script:module $script:NewSite 'TestSite'
        }

        It 'Should add a subnet to the site' {
            $script:testSite.AddSubnet('192.168.1.0/24')

            $script:testSite.Subnets.Count | Should -Be 1
            $script:testSite.Subnets | Should -Contain '192.168.1.0/24'
        }

        It 'Should add multiple subnets' {
            $script:testSite.AddSubnet('192.168.1.0/24')
            $script:testSite.AddSubnet('192.168.2.0/24')
            $script:testSite.AddSubnet('10.0.0.0/8')

            $script:testSite.Subnets.Count | Should -Be 3
            $script:testSite.Subnets | Should -Contain '192.168.1.0/24'
            $script:testSite.Subnets | Should -Contain '192.168.2.0/24'
            $script:testSite.Subnets | Should -Contain '10.0.0.0/8'
        }

        It 'Should not add duplicate subnet' {
            $script:testSite.AddSubnet('192.168.1.0/24')
            $script:testSite.AddSubnet('192.168.1.0/24')

            $script:testSite.Subnets.Count | Should -Be 1
        }

        It 'Should accept empty string as subnet' {
            $script:testSite.AddSubnet('')

            $script:testSite.Subnets.Count | Should -Be 1
            $script:testSite.Subnets | Should -Contain ''
        }
    }

    Context 'RemoveSubnet Method' {
        BeforeEach {
            $script:testSite = & $script:module $script:NewSite 'TestSite'
            $script:testSite.AddSubnet('192.168.1.0/24')
            $script:testSite.AddSubnet('192.168.2.0/24')
            $script:testSite.AddSubnet('10.0.0.0/8')
        }

        It 'Should remove an existing subnet' {
            $result = $script:testSite.RemoveSubnet('192.168.1.0/24')

            $result | Should -Be $true
            $script:testSite.Subnets.Count | Should -Be 2
            $script:testSite.Subnets | Should -Not -Contain '192.168.1.0/24'
        }

        It 'Should return false when removing non-existent subnet' {
            $result = $script:testSite.RemoveSubnet('172.16.0.0/12')

            $result | Should -Be $false
            $script:testSite.Subnets.Count | Should -Be 3
        }

        It 'Should maintain other subnets when removing one' {
            $script:testSite.RemoveSubnet('192.168.2.0/24')

            $script:testSite.Subnets | Should -Contain '192.168.1.0/24'
            $script:testSite.Subnets | Should -Contain '10.0.0.0/8'
        }
    }

    Context 'AddSiteLink Method' {
        BeforeEach {
            $script:testSite = & $script:module $script:NewSite 'TestSite'
        }

        It 'Should add a site link to the site' {
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')

            $script:testSite.SiteLinks.Count | Should -Be 1
            $script:testSite.SiteLinks | Should -Contain 'DEFAULTIPSITELINK'
        }

        It 'Should add multiple site links' {
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')
            $script:testSite.AddSiteLink('PARIS-LONDON')
            $script:testSite.AddSiteLink('PARIS-BERLIN')

            $script:testSite.SiteLinks.Count | Should -Be 3
            $script:testSite.SiteLinks | Should -Contain 'DEFAULTIPSITELINK'
            $script:testSite.SiteLinks | Should -Contain 'PARIS-LONDON'
            $script:testSite.SiteLinks | Should -Contain 'PARIS-BERLIN'
        }

        It 'Should not add duplicate site link' {
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')

            $script:testSite.SiteLinks.Count | Should -Be 1
        }
    }

    Context 'RemoveSiteLink Method' {
        BeforeEach {
            $script:testSite = & $script:module $script:NewSite 'TestSite'
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')
            $script:testSite.AddSiteLink('PARIS-LONDON')
            $script:testSite.AddSiteLink('PARIS-BERLIN')
        }

        It 'Should remove an existing site link' {
            $result = $script:testSite.RemoveSiteLink('PARIS-LONDON')

            $result | Should -Be $true
            $script:testSite.SiteLinks.Count | Should -Be 2
            $script:testSite.SiteLinks | Should -Not -Contain 'PARIS-LONDON'
        }

        It 'Should return false when removing non-existent site link' {
            $result = $script:testSite.RemoveSiteLink('NONEXISTENT')

            $result | Should -Be $false
            $script:testSite.SiteLinks.Count | Should -Be 3
        }

        It 'Should maintain other site links when removing one' {
            $script:testSite.RemoveSiteLink('PARIS-LONDON')

            $script:testSite.SiteLinks | Should -Contain 'DEFAULTIPSITELINK'
            $script:testSite.SiteLinks | Should -Contain 'PARIS-BERLIN'
        }
    }

    Context 'ToHashtable Method' {
        BeforeEach {
            $script:testSite = & $script:module $script:NewSite 'Paris' 'Main office' 'Paris, France'
            $script:testSite.DistinguishedName = 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
            $script:testSite.AddSubnet('192.168.1.0/24')
            $script:testSite.AddSiteLink('DEFAULTIPSITELINK')
            $script:testSite.WhenCreated = Get-Date '2024-01-01 10:00:00'
            $script:testSite.WhenChanged = Get-Date '2024-01-15 14:30:00'
        }

        It 'Should return a hashtable' {
            $result = $script:testSite.ToHashtable()

            $result | Should -BeOfType [hashtable]
        }

        It 'Should include all properties in hashtable' {
            $result = $script:testSite.ToHashtable()

            $result.Keys | Should -Contain 'Name'
            $result.Keys | Should -Contain 'Description'
            $result.Keys | Should -Contain 'Location'
            $result.Keys | Should -Contain 'DistinguishedName'
            $result.Keys | Should -Contain 'Subnets'
            $result.Keys | Should -Contain 'SiteLinks'
            $result.Keys | Should -Contain 'WhenCreated'
            $result.Keys | Should -Contain 'WhenChanged'
            $result.Keys | Should -Contain 'Options'
        }

        It 'Should have correct values in hashtable' {
            $result = $script:testSite.ToHashtable()

            $result.Name | Should -Be 'Paris'
            $result.Description | Should -Be 'Main office'
            $result.Location | Should -Be 'Paris, France'
            $result.DistinguishedName | Should -Be 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
            $result.Subnets.Count | Should -Be 1
            $result.SiteLinks.Count | Should -Be 1
        }
    }

    Context 'ToString Method' {
        It 'Should return formatted string with site information' {
            $site = & $script:module $script:NewSite 'Paris'
            $site.AddSubnet('192.168.1.0/24')
            $site.AddSubnet('192.168.2.0/24')
            $site.AddSiteLink('DEFAULTIPSITELINK')

            $result = $site.ToString()

            $result | Should -Match 'Site: Paris'
            $result | Should -Match 'Subnets: 2'
            $result | Should -Match 'SiteLinks: 1'
        }

        It 'Should handle site with no subnets or links' {
            $site = & $script:module $script:NewSite 'London'

            $result = $site.ToString()

            $result | Should -Match 'Site: London'
            $result | Should -Match 'Subnets: 0'
            $result | Should -Match 'SiteLinks: 0'
        }
    }

    Context 'FromADObject Static Method' {
        BeforeEach {
            # Mock an Active Directory site object
            $script:mockADSite = [PSCustomObject]@{
                Name               = 'Paris'
                Description        = 'Main office in Paris'
                Location           = 'Paris, France'
                DistinguishedName  = 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                WhenCreated        = Get-Date '2024-01-01 10:00:00'
                WhenChanged        = Get-Date '2024-01-15 14:30:00'
                siteObjectBL       = @(
                    'CN=192.168.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com',
                    'CN=192.168.2.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                )
            }
        }

        It 'Should create SITE instance from AD object' {
            $site = & $script:module $script:FromADObject $script:mockADSite

            $site | Should -Not -BeNullOrEmpty
        }

        It 'Should populate basic properties from AD object' {
            $site = & $script:module $script:FromADObject $script:mockADSite

            $site.Name | Should -Be 'Paris'
            $site.Description | Should -Be 'Main office in Paris'
            $site.Location | Should -Be 'Paris, France'
            $site.DistinguishedName | Should -Be 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        }

        It 'Should populate temporal properties from AD object' {
            $site = & $script:module $script:FromADObject $script:mockADSite

            $site.WhenCreated | Should -Be $script:mockADSite.WhenCreated
            $site.WhenChanged | Should -Be $script:mockADSite.WhenChanged
        }

        It 'Should populate subnets from siteObjectBL property' {
            $site = & $script:module $script:FromADObject $script:mockADSite

            $site.Subnets.Count | Should -Be 2
            $site.Subnets | Should -Contain 'CN=192.168.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
            $site.Subnets | Should -Contain 'CN=192.168.2.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        }

        It 'Should handle AD object without siteObjectBL property' {
            $mockADSiteNoSubnets = [PSCustomObject]@{
                Name               = 'London'
                Description        = 'Office in London'
                Location           = 'London, UK'
                DistinguishedName  = 'CN=London,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                WhenCreated        = Get-Date '2024-02-01 10:00:00'
                WhenChanged        = Get-Date '2024-02-15 14:30:00'
            }

            $site = & $script:module $script:FromADObject $mockADSiteNoSubnets

            $site.Subnets.Count | Should -Be 0
        }

        It 'Should handle AD object with empty siteObjectBL' {
            $mockADSiteEmptySubnets = [PSCustomObject]@{
                Name               = 'Berlin'
                Description        = 'Office in Berlin'
                Location           = 'Berlin, Germany'
                DistinguishedName  = 'CN=Berlin,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                WhenCreated        = Get-Date '2024-03-01 10:00:00'
                WhenChanged        = Get-Date '2024-03-15 14:30:00'
                siteObjectBL       = @()
            }

            $site = & $script:module $script:FromADObject $mockADSiteEmptySubnets

            $site.Subnets.Count | Should -Be 0
        }

        It 'Should handle AD object with null Description' {
            $mockADSiteNullDesc = [PSCustomObject]@{
                Name               = 'Madrid'
                Description        = $null
                Location           = 'Madrid, Spain'
                DistinguishedName  = 'CN=Madrid,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                WhenCreated        = Get-Date '2024-04-01 10:00:00'
                WhenChanged        = Get-Date '2024-04-15 14:30:00'
            }

            $site = & $script:module $script:FromADObject $mockADSiteNullDesc

            $site.Description | Should -BeNullOrEmpty
            $site.Name | Should -Be 'Madrid'
        }
    }

    Context 'Options Property' {
        It 'Should allow adding custom options' {
            $site = & $script:module $script:NewSite 'TestSite'
            $site.Options['CustomProperty'] = 'CustomValue'
            $site.Options['ReplicationSchedule'] = 'Hourly'

            $site.Options['CustomProperty'] | Should -Be 'CustomValue'
            $site.Options['ReplicationSchedule'] | Should -Be 'Hourly'
            $site.Options.Count | Should -Be 2
        }

        It 'Should allow updating existing options' {
            $site = & $script:module $script:NewSite 'TestSite'
            $site.Options['Status'] = 'Active'
            $site.Options['Status'] = 'Inactive'

            $site.Options['Status'] | Should -Be 'Inactive'
            $site.Options.Count | Should -Be 1
        }

        It 'Should allow removing options' {
            $site = & $script:module $script:NewSite 'TestSite'
            $site.Options['Temporary'] = 'Value'
            $site.Options.Remove('Temporary')

            $site.Options.ContainsKey('Temporary') | Should -Be $false
            $site.Options.Count | Should -Be 0
        }
    }

    Context 'Integration Scenarios' {
        It 'Should handle complete site lifecycle' {
            # Create site
            $site = & $script:module $script:NewSite 'Paris' 'Main office' 'Paris, France'

            # Add subnets
            $site.AddSubnet('192.168.1.0/24')
            $site.AddSubnet('192.168.2.0/24')

            # Add site links
            $site.AddSiteLink('DEFAULTIPSITELINK')
            $site.AddSiteLink('PARIS-LONDON')

            # Add custom options
            $site.Options['ReplicationInterval'] = 180
            $site.Options['Environment'] = 'Production'

            # Verify complete state
            $site.Name | Should -Be 'Paris'
            $site.Subnets.Count | Should -Be 2
            $site.SiteLinks.Count | Should -Be 2
            $site.Options.Count | Should -Be 2
        }

        It 'Should convert to hashtable and preserve all data' {
            $site = & $script:module $script:NewSite 'TestSite'
            $site.AddSubnet('10.0.0.0/8')
            $site.AddSiteLink('TESTLINK')
            $site.Options['CustomOption'] = 'TestValue'

            $hashtable = $site.ToHashtable()

            $hashtable.Name | Should -Be 'TestSite'
            $hashtable.Subnets | Should -Contain '10.0.0.0/8'
            $hashtable.SiteLinks | Should -Contain 'TESTLINK'
            $hashtable.Options['CustomOption'] | Should -Be 'TestValue'
        }

        It 'Should handle multiple operations in sequence' {
            $site = & $script:module $script:NewSite 'MultiOpSite'

            # Add and remove subnets
            $site.AddSubnet('192.168.1.0/24')
            $site.AddSubnet('192.168.2.0/24')
            $site.AddSubnet('192.168.3.0/24')
            $site.RemoveSubnet('192.168.2.0/24')

            # Add and remove site links
            $site.AddSiteLink('LINK1')
            $site.AddSiteLink('LINK2')
            $site.RemoveSiteLink('LINK1')

            # Verify final state
            $site.Subnets.Count | Should -Be 2
            $site.Subnets | Should -Contain '192.168.1.0/24'
            $site.Subnets | Should -Contain '192.168.3.0/24'
            $site.SiteLinks.Count | Should -Be 1
            $site.SiteLinks | Should -Contain 'LINK2'
        }
    }

    Context 'Type Validation' {
        It 'Should accept only string type for Name in constructor' {
            { & $script:module $script:NewSite 'ValidName' } | Should -Not -Throw
        }

        It 'Should accept string types for Description and Location in constructor' {
            { & $script:module $script:NewSite 'Site' 'Description' 'Location' } | Should -Not -Throw
        }

        It 'Subnets should be ArrayList type' {
            $site = & $script:module $script:NewSite
            $site.Subnets.GetType().Name | Should -Be 'ArrayList'
        }

        It 'SiteLinks should be ArrayList type' {
            $site = & $script:module $script:NewSite
            $site.SiteLinks.GetType().Name | Should -Be 'ArrayList'
        }

        It 'Options should be hashtable type' {
            $site = & $script:module $script:NewSite
            $site.Options.GetType().Name | Should -Be 'Hashtable'
        }
    }
}
