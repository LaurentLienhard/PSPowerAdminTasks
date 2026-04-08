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

Describe 'Invoke-ServerDnsCheckSequential' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should be defined in the module' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $fn | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a mandatory Computers parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $fn.Parameters['Computers'].Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have a mandatory DnsServer parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $fn.Parameters['DnsServer'].Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have an optional TimeoutSeconds parameter' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $fn.Parameters['TimeoutSeconds'] | Should -Not -BeNullOrEmpty
        }

        It 'Should not have a ThrottleLimit parameter (sequential)' {
            $fn = & (Get-Module $script:moduleName) { Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $fn.Parameters.ContainsKey('ThrottleLimit') | Should -BeFalse
        }
    }

    Context 'Help Documentation' {

        It 'Should have a synopsis' {
            $help = & (Get-Module $script:moduleName) { Get-Help -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue }
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - No Ping Response' {

        It 'Should return an empty array when no computers respond to ping' {
            $result = & (Get-Module $script:moduleName) {
                $fakeComputers = @(
                    [PSCustomObject]@{ Name = 'OFFLINE-SRV'; OperatingSystem = 'Windows Server 2019'; Description = '' }
                )
                Invoke-ServerDnsCheckSequential -Computers $fakeComputers -DnsServer '10.0.0.1' -TimeoutSeconds 1
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Execution - Empty Computer List' {

        It 'Should return an empty result for an empty computer list' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-ServerDnsCheckSequential -Computers @() -DnsServer '10.0.0.1'
            }
            @($result).Count | Should -Be 0
        }
    }
}
