BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }

    # Create mock AD site objects
    $script:mockSite1 = [PSCustomObject]@{
        Name               = 'Default-First-Site-Name'
        Description        = 'Default site'
        Location           = 'Main Office'
        DistinguishedName  = 'CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        WhenCreated        = Get-Date '2024-01-01 10:00:00'
        WhenChanged        = Get-Date '2024-01-15 14:30:00'
        siteObjectBL       = @(
            'CN=192.168.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com',
            'CN=192.168.2.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        )
    }

    $script:mockSite2 = [PSCustomObject]@{
        Name               = 'Paris'
        Description        = 'Paris office'
        Location           = 'Paris, France'
        DistinguishedName  = 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        WhenCreated        = Get-Date '2024-02-01 10:00:00'
        WhenChanged        = Get-Date '2024-02-15 14:30:00'
        siteObjectBL       = @(
            'CN=10.0.0.0/8,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        )
    }

    $script:mockSite3 = [PSCustomObject]@{
        Name               = 'London'
        Description        = 'London office'
        Location           = 'London, UK'
        DistinguishedName  = 'CN=London,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        WhenCreated        = Get-Date '2024-03-01 10:00:00'
        WhenChanged        = Get-Date '2024-03-15 14:30:00'
        siteObjectBL       = $null
    }

    # Mock site links with cost information
    $script:mockSiteLink1 = [PSCustomObject]@{
        Name                            = 'DEFAULTIPSITELINK'
        Description                     = 'Default site link'
        Cost                           = 100
        ReplicationFrequencyInMinutes   = 180
        ReplaceWithInterSiteTopology   = $false
        DistinguishedName              = 'CN=DEFAULTIPSITELINK,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        WhenCreated                    = Get-Date '2024-01-01 10:00:00'
        WhenChanged                    = Get-Date '2024-01-15 14:30:00'
        SiteList                       = @(
            'CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=contoso,DC=com',
            'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        )
    }

    $script:mockSiteLink2 = [PSCustomObject]@{
        Name                            = 'PARIS-LONDON'
        Description                     = 'Paris to London link'
        Cost                           = 50
        ReplicationFrequencyInMinutes   = 120
        ReplaceWithInterSiteTopology   = $false
        DistinguishedName              = 'CN=PARIS-LONDON,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        WhenCreated                    = Get-Date '2024-02-01 10:00:00'
        WhenChanged                    = Get-Date '2024-02-15 14:30:00'
        SiteList                       = @(
            'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com',
            'CN=London,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        )
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
}

Describe 'Get-SiteInformation' -Tag 'Unit', 'Public' {
    BeforeAll {
        # Mock ActiveDirectory commands globally for all tests
        Mock -CommandName Get-Module -MockWith {
            return @{
                Name = 'ActiveDirectory'
                Version = '1.0.0'
            }
        } -ParameterFilter { $Name -eq 'ActiveDirectory' }

        Mock -CommandName Import-Module -MockWith { } -ParameterFilter { $Name -eq 'ActiveDirectory' }
        Mock -CommandName Write-Verbose -MockWith { }
        Mock -CommandName Write-Warning -MockWith { }
        Mock -CommandName Write-Error -MockWith { }
    }

    Context 'Parameter Validation' {
        It 'Should have Name as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept Name from pipeline' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.ValueFromPipeline | Should -Contain $true
        }

        It 'Should accept Name from pipeline by property name' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Name'].Attributes.ValueFromPipelineByPropertyName | Should -Contain $true
        }

        It 'Should support wildcards for Name parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $nameParam = $command.Parameters['Name']
            $supportsWildcards = $nameParam.Attributes | Where-Object { $_.TypeId.Name -eq 'SupportsWildcardsAttribute' }
            $supportsWildcards | Should -Not -BeNullOrEmpty
        }

        It 'Should have Server as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Server'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have Credential as optional parameter' {
            $command = Get-Command -Name Get-SiteInformation
            $command.Parameters['Credential'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should output SITE array type' {
            $command = Get-Command -Name Get-SiteInformation
            $outputType = $command.OutputType.Type.Name
            $outputType | Should -Be 'SITE[]'
        }
    }

    Context 'ActiveDirectory Module Availability' {
        It 'Should check for ActiveDirectory module when not available' {
            Mock -CommandName Get-Module -MockWith { return $null } -ParameterFilter { $Name -eq 'ActiveDirectory' -and $ListAvailable }

            $result = Get-SiteInformation -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Get-Module -ParameterFilter { $Name -eq 'ActiveDirectory' -and $ListAvailable } -Times 1
            Should -Invoke -CommandName Write-Error -Times 1
            $result | Should -BeNullOrEmpty
        }

        It 'Should import ActiveDirectory module if not loaded' {
            Mock -CommandName Get-Module -MockWith { return $null } -ParameterFilter { $Name -eq 'ActiveDirectory' -and -not $ListAvailable }
            Mock -CommandName Get-Module -MockWith {
                return @{ Name = 'ActiveDirectory' }
            } -ParameterFilter { $Name -eq 'ActiveDirectory' -and $ListAvailable }
            Mock -CommandName Get-ADReplicationSite -MockWith { return @() }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith { return @() }

            Get-SiteInformation -Verbose

            Should -Invoke -CommandName Import-Module -ParameterFilter { $Name -eq 'ActiveDirectory' } -Times 1
        }
    }

    Context 'Retrieving All Sites' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return @($script:mockSite1, $script:mockSite2, $script:mockSite3)
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @($script:mockSiteLink1)
            }
        }

        It 'Should return all sites when no Name parameter is provided' {
            $result = Get-SiteInformation

            $result.Count | Should -Be 3
            $result[0].GetType().Name | Should -Be 'SITE'
        }

        It 'Should call Get-ADReplicationSite with wildcard filter' {
            Get-SiteInformation

            Should -Invoke -CommandName Get-ADReplicationSite -Times 1 -ParameterFilter {
                $Filter -like "*Name -like '*'*"
            }
        }

        It 'Should populate SITE objects with correct properties' {
            $result = Get-SiteInformation

            $site = $result | Where-Object { $_.Name -eq 'Default-First-Site-Name' }
            $site.Name | Should -Be 'Default-First-Site-Name'
            $site.Description | Should -Be 'Default site'
            $site.Location | Should -Be 'Main Office'
            $site.DistinguishedName | Should -Be 'CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        }

        It 'Should populate subnets from siteObjectBL' {
            $result = Get-SiteInformation

            $site = $result | Where-Object { $_.Name -eq 'Default-First-Site-Name' }
            $site.Subnets.Count | Should -Be 2
            $site.Subnets | Should -Contain 'CN=192.168.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        }

        It 'Should query and add site links' {
            $result = Get-SiteInformation

            Should -Invoke -CommandName Get-ADReplicationSiteLink -Times 3
            $result[0].SiteLinks.Count | Should -BeGreaterOrEqual 0
        }
    }

    Context 'Retrieving Specific Site by Name' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite2
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return $script:mockSiteLink2
            }
        }

        It 'Should return specific site when Name is provided' {
            $result = Get-SiteInformation -Name 'Paris'

            $result.Count | Should -Be 1
            $result.Name | Should -Be 'Paris'
        }

        It 'Should call Get-ADReplicationSite with specific filter' {
            Get-SiteInformation -Name 'Paris'

            Should -Invoke -CommandName Get-ADReplicationSite -Times 1 -ParameterFilter {
                $Filter -like "*Name -like 'Paris'*"
            }
        }

        It 'Should populate site link correctly' {
            $result = Get-SiteInformation -Name 'Paris'

            $result.SiteLinks.Count | Should -Be 1
            $result.SiteLinks[0].Name | Should -Be 'PARIS-LONDON'
            $result.SiteLinks[0].Cost | Should -Be 50
            $result.SiteLinks[0].ReplicationFrequency | Should -Be 120
        }

        It 'Should calculate total inter-site cost correctly' {
            $result = Get-SiteInformation -Name 'Paris'

            $result.TotalInterSiteCost | Should -Be 50
        }
    }

    Context 'Wildcard Support' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return @($script:mockSite2, $script:mockSite3)
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should support wildcard patterns' {
            $result = Get-SiteInformation -Name '*on*'

            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'Paris'
            $result.Name | Should -Contain 'London'
        }
    }

    Context 'Multiple Site Names' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                param($Filter)
                if ($Filter -like "*Paris*") {
                    return $script:mockSite2
                } elseif ($Filter -like "*London*") {
                    return $script:mockSite3
                }
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should handle array of site names' {
            $result = Get-SiteInformation -Name 'Paris', 'London'

            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'Paris'
            $result.Name | Should -Contain 'London'
        }
    }

    Context 'Pipeline Input' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                param($Filter)
                if ($Filter -like "*Paris*") {
                    return $script:mockSite2
                } elseif ($Filter -like "*London*") {
                    return $script:mockSite3
                }
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should accept site names from pipeline' {
            $result = 'Paris', 'London' | Get-SiteInformation

            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'Paris'
            $result.Name | Should -Contain 'London'
        }
    }

    Context 'Server and Credential Parameters' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite1
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should pass Server parameter to AD cmdlets' {
            Get-SiteInformation -Server 'DC01.contoso.com'

            Should -Invoke -CommandName Get-ADReplicationSite -Times 1 -ParameterFilter {
                $Server -eq 'DC01.contoso.com'
            }
        }

        It 'Should pass Credential parameter to AD cmdlets' {
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'testpass' -AsPlainText -Force))
            Get-SiteInformation -Credential $cred

            Should -Invoke -CommandName Get-ADReplicationSite -Times 1 -ParameterFilter {
                $null -ne $Credential
            }
        }

        It 'Should pass both Server and Credential parameters' {
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'testpass' -AsPlainText -Force))
            Get-SiteInformation -Server 'DC01.contoso.com' -Credential $cred

            Should -Invoke -CommandName Get-ADReplicationSite -Times 1 -ParameterFilter {
                $Server -eq 'DC01.contoso.com' -and $null -ne $Credential
            }
        }
    }

    Context 'Error Handling' {
        It 'Should handle non-existent sites gracefully' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $null
            }

            $result = Get-SiteInformation -Name 'NonExistentSite'

            $result.Count | Should -Be 0
            Should -Invoke -CommandName Write-Warning -Times 1
        }

        It 'Should handle errors when querying AD sites' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                throw "Access denied"
            }

            Get-SiteInformation -Name 'TestSite' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Write-Error -Times 1
        }

        It 'Should handle errors when querying site links and continue' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite1
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                throw "Cannot retrieve site links"
            }

            $result = Get-SiteInformation -Name 'Default-First-Site-Name'

            $result | Should -Not -BeNullOrEmpty
            $result.SiteLinks.Count | Should -Be 0
            Should -Invoke -CommandName Write-Warning -Times 1
        }
    }

    Context 'Verbose Output' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite1
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should write verbose messages when -Verbose is used' {
            Get-SiteInformation -Verbose

            Should -Invoke -CommandName Write-Verbose -Times 1 -ParameterFilter {
                $Message -like '*Starting AD Sites query*'
            }
        }

        It 'Should write verbose message for each site processed' {
            Get-SiteInformation -Verbose

            Should -Invoke -CommandName Write-Verbose -Times 1 -ParameterFilter {
                $Message -like '*Processing site:*'
            }
        }

        It 'Should write verbose completion message' {
            Get-SiteInformation -Verbose

            Should -Invoke -CommandName Write-Verbose -Times 1 -ParameterFilter {
                $Message -like '*Query complete*'
            }
        }
    }

    Context 'Integration with SITE Class' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite2
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return $script:mockSiteLink2
            }
        }

        It 'Should use SITE::FromADObject static method' {
            $result = Get-SiteInformation -Name 'Paris'

            $result.GetType().Name | Should -Be 'SITE'
            $result.Name | Should -Be 'Paris'
        }

        It 'Should use AddSiteLink method to add site links' {
            $result = Get-SiteInformation -Name 'Paris'

            $result.SiteLinks.Count | Should -Be 1
            $result.SiteLinks[0].Name | Should -Be 'PARIS-LONDON'
        }

        It 'Should create SITELINK objects with correct properties' {
            $result = Get-SiteInformation -Name 'Paris'

            $siteLink = $result.SiteLinks[0]
            $siteLink.GetType().Name | Should -Be 'SITELINK'
            $siteLink.Name | Should -Be 'PARIS-LONDON'
            $siteLink.Cost | Should -Be 50
            $siteLink.ReplicationFrequency | Should -Be 120
        }
    }

    Context 'Edge Cases' {
        It 'Should handle site with no description' {
            $mockSiteNoDesc = [PSCustomObject]@{
                Name               = 'NoDescSite'
                Description        = $null
                Location           = 'Somewhere'
                DistinguishedName  = 'CN=NoDescSite,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                WhenCreated        = Get-Date
                WhenChanged        = Get-Date
                siteObjectBL       = $null
            }

            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $mockSiteNoDesc
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }

            $result = Get-SiteInformation -Name 'NoDescSite'

            $result.Name | Should -Be 'NoDescSite'
            $result.Description | Should -BeNullOrEmpty
        }

        It 'Should handle site with no subnets' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite3
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }

            $result = Get-SiteInformation -Name 'London'

            $result.Subnets.Count | Should -Be 0
        }

        It 'Should handle site with no site links' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $script:mockSite1
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }

            $result = Get-SiteInformation -Name 'Default-First-Site-Name'

            $result.SiteLinks.Count | Should -Be 0
        }
    }

    Context 'Return Type' {
        BeforeAll {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return @($script:mockSite1, $script:mockSite2)
            }
            Mock -CommandName Get-ADReplicationSiteLink -MockWith {
                return @()
            }
        }

        It 'Should return an array of SITE objects' {
            $result = Get-SiteInformation

            $result | Should -BeOfType [Array]
            $result[0].GetType().Name | Should -Be 'SITE'
            $result[1].GetType().Name | Should -Be 'SITE'
        }

        It 'Should return empty array when no sites found' {
            Mock -CommandName Get-ADReplicationSite -MockWith {
                return $null
            }

            $result = Get-SiteInformation -Name 'NonExistent'

            $result.Count | Should -Be 0
        }
    }
}
