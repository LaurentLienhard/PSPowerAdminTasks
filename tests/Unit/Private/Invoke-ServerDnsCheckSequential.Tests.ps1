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

    Context 'Execution - Empty Computer List' {

        It 'Should return an empty result for an empty computer list' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-ServerDnsCheckSequential -Computers @() -DnsServer '10.0.0.1'
            }
            @($result).Count | Should -Be 0
        }
    }

    Context 'Execution - No Ping Response' {

        BeforeAll {
            # Mock Test-Connection so no real network calls are made
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { return $false }
        }

        It 'Should return an empty array when no computers respond to ping' {
            $result = & (Get-Module $script:moduleName) {
                $fakeComputers = @(
                    [PSCustomObject]@{ Name = 'OFFLINE-SRV'; OperatingSystem = 'Windows Server 2019'; Description = '' }
                )
                Invoke-ServerDnsCheckSequential -Computers $fakeComputers -DnsServer '10.0.0.1'
            }
            @($result).Count | Should -Be 0
        }

        It 'Should call Test-Connection for each computer' {
            & (Get-Module $script:moduleName) {
                $fakeComputers = @(
                    [PSCustomObject]@{ Name = 'OFFLINE-SRV'; OperatingSystem = 'Windows Server 2019'; Description = '' }
                )
                Invoke-ServerDnsCheckSequential -Computers $fakeComputers -DnsServer '10.0.0.1'
            }
            Should -Invoke -CommandName Test-Connection -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }
}
