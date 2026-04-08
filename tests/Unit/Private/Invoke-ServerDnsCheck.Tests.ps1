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

    Context 'Execution - Empty Computer List' {

        It 'Should return an empty result for an empty computer list' {
            # Empty list does not enter the parallel block — no network calls
            $result = & (Get-Module $script:moduleName) {
                Invoke-ServerDnsCheck -Computers @() -DnsServer '10.0.0.1'
            }
            @($result).Count | Should -Be 0
        }
    }
}
