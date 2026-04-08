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

Describe 'Invoke-ServerDnsCheck' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should be defined in the module' {
            # Private functions are accessible via the module's internal scope
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $fn | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a mandatory Computers parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $fn.Parameters['Computers'].Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have a mandatory DnsServer parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $fn.Parameters['DnsServer'].Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have an optional TimeoutSeconds parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $fn.Parameters['TimeoutSeconds'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have an optional ThrottleLimit parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $fn.Parameters['ThrottleLimit'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {

        It 'Should have a synopsis' {
            $help = & (Get-Module $script:moduleName) { Get-Help -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue }
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - No Ping Response' {

        It 'Should return no results when computers do not respond to ping' {
            $result = & (Get-Module $script:moduleName) {
                $fakeComputers = @(
                    [PSCustomObject]@{ Name = 'OFFLINE-SRV'; OperatingSystem = 'Windows Server 2019'; Description = '' }
                )
                # Test-Connection will fail for a non-existent host
                Invoke-ServerDnsCheck -Computers $fakeComputers -DnsServer '10.0.0.1' -TimeoutSeconds 1
            }
            $result | Should -BeNullOrEmpty
        }
    }
}
