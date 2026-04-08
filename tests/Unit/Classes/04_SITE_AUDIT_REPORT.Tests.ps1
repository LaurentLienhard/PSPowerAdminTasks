BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (-not (Test-Path $modulePath)) {
        $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    }
    if (-not (Test-Path $modulePath)) {
        $modulePath = "$PSScriptRoot/../../../source"
    }

    $script:module = Import-Module (Join-Path $modulePath "$script:moduleName.psd1") -Force -ErrorAction Stop -PassThru
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'SiteAuditReport Class' -Tag 'Unit' {

    Context 'Constructor - Default' {

        It 'Should create an instance without throwing' {
            { & (Get-Module $script:moduleName) { [SiteAuditReport]::new() } } | Should -Not -Throw
        }

        It 'Should initialize AuditDate to current date' {
            $report = & (Get-Module $script:moduleName) { [SiteAuditReport]::new() }
            $report.AuditDate | Should -Not -BeNullOrEmpty
            $report.AuditDate | Should -BeOfType [datetime]
        }

        It 'Should initialize AllSites as an empty list' {
            $report = & (Get-Module $script:moduleName) { [SiteAuditReport]::new() }
            $report.AllSites | Should -Not -BeNullOrEmpty
            $report.AllSites.Count | Should -Be 0
        }

        It 'Should initialize EmptySites as an empty list' {
            $report = & (Get-Module $script:moduleName) { [SiteAuditReport]::new() }
            $report.EmptySites | Should -Not -BeNullOrEmpty
            $report.EmptySites.Count | Should -Be 0
        }

        It 'Should initialize SitesWithoutDCs as an empty list' {
            $report = & (Get-Module $script:moduleName) { [SiteAuditReport]::new() }
            $report.SitesWithoutDCs | Should -Not -BeNullOrEmpty
            $report.SitesWithoutDCs.Count | Should -Be 0
        }

        It 'Should initialize OrphanSubnets as an empty list' {
            $report = & (Get-Module $script:moduleName) { [SiteAuditReport]::new() }
            $report.OrphanSubnets | Should -Not -BeNullOrEmpty
            $report.OrphanSubnets.Count | Should -Be 0
        }
    }

    Context 'AllSites List Operations' {

        It 'Should allow adding SITE objects to AllSites' {
            $report = & (Get-Module $script:moduleName) {
                $r = [SiteAuditReport]::new()
                $s = [SITE]::new()
                $s.Name = 'TestSite'
                $r.AllSites.Add($s)
                $r
            }
            $report.AllSites.Count | Should -Be 1
        }
    }

    Context 'EmptySites List Operations' {

        It 'Should allow adding SITE objects to EmptySites' {
            $report = & (Get-Module $script:moduleName) {
                $r = [SiteAuditReport]::new()
                $s = [SITE]::new()
                $s.Name = 'EmptySite'
                $r.EmptySites.Add($s)
                $r
            }
            $report.EmptySites.Count | Should -Be 1
        }
    }

    Context 'SitesWithoutDCs List Operations' {

        It 'Should allow adding SITE objects to SitesWithoutDCs' {
            $report = & (Get-Module $script:moduleName) {
                $r = [SiteAuditReport]::new()
                $s = [SITE]::new()
                $s.Name = 'NoDCSite'
                $r.SitesWithoutDCs.Add($s)
                $r
            }
            $report.SitesWithoutDCs.Count | Should -Be 1
        }
    }

    Context 'OrphanSubnets List Operations' {

        It 'Should allow adding subnet strings to OrphanSubnets' {
            $report = & (Get-Module $script:moduleName) {
                $r = [SiteAuditReport]::new()
                $r.OrphanSubnets.Add('192.168.99.0/24')
                $r
            }
            $report.OrphanSubnets.Count | Should -Be 1
            $report.OrphanSubnets[0] | Should -Be '192.168.99.0/24'
        }

        It 'Should allow adding multiple orphan subnets' {
            $report = & (Get-Module $script:moduleName) {
                $r = [SiteAuditReport]::new()
                $r.OrphanSubnets.Add('10.0.99.0/24')
                $r.OrphanSubnets.Add('172.16.99.0/24')
                $r
            }
            $report.OrphanSubnets.Count | Should -Be 2
        }
    }
}
