BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    else {
        $sourcePath = "$PSScriptRoot/../../../source/$script:moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SiteTopologyAudit' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Get-SiteTopologyAudit -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-SiteTopologyAudit -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have an optional Server parameter' {
            $param = (Get-Command -Name Get-SiteTopologyAudit -Module $script:moduleName).Parameters['Server']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have an optional Credential parameter' {
            $param = (Get-Command -Name Get-SiteTopologyAudit -Module $script:moduleName).Parameters['Credential']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Get-SiteTopologyAudit -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Get-SiteTopologyAudit -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Get-SiteTopologyAudit -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - All Sites Have Subnets and DCs' {

        BeforeAll {
            Mock -CommandName Get-SiteInformation -ModuleName $script:moduleName -MockWith {
                $site1 = & (Get-Module $using:moduleName) {
                    $s = [SITE]::new()
                    $s.Name = 'Site-A'
                    $s.Subnets.Add('10.0.1.0/24')
                    $s.DomainControllers.Add('DC01')
                    $s
                }
                $site2 = & (Get-Module $using:moduleName) {
                    $s = [SITE]::new()
                    $s.Name = 'Site-B'
                    $s.Subnets.Add('10.0.2.0/24')
                    $s.DomainControllers.Add('DC02')
                    $s
                }
                return @($site1, $site2)
            }

            Mock -CommandName Get-ADReplicationSubnet -ModuleName $script:moduleName -MockWith { return @() }
            Mock -CommandName Write-Host -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call Get-SiteInformation' {
            Get-SiteTopologyAudit
            Should -Invoke -CommandName Get-SiteInformation -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should return a SiteAuditReport object' {
            $result = Get-SiteTopologyAudit
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should report zero empty sites when all sites have subnets' {
            $result = Get-SiteTopologyAudit
            $result.EmptySites.Count | Should -Be 0
        }

        It 'Should report zero orphan subnets' {
            $result = Get-SiteTopologyAudit
            $result.OrphanSubnets.Count | Should -Be 0
        }
    }

    Context 'Execution - Sites Without Subnets and DCs' {

        BeforeAll {
            $script:moduleName = 'PSPowerAdminTasks'

            Mock -CommandName Get-SiteInformation -ModuleName $script:moduleName -MockWith {
                $emptySite = & (Get-Module $using:moduleName) {
                    $s = [SITE]::new()
                    $s.Name = 'EmptySite'
                    $s
                }
                return @($emptySite)
            }

            Mock -CommandName Get-ADReplicationSubnet -ModuleName $script:moduleName -MockWith {
                @([PSCustomObject]@{ Name = '192.168.99.0/24' })
            }

            Mock -CommandName Write-Host -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should report one empty site when a site has no subnets' {
            $result = Get-SiteTopologyAudit
            $result.EmptySites.Count | Should -Be 1
        }

        It 'Should report one site without DCs' {
            $result = Get-SiteTopologyAudit
            $result.SitesWithoutDCs.Count | Should -Be 1
        }

        It 'Should report orphan subnets' {
            $result = Get-SiteTopologyAudit
            $result.OrphanSubnets.Count | Should -Be 1
        }
    }
}
