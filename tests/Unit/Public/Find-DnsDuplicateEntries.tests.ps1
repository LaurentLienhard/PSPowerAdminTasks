BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$script:moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Find-DnsDuplicateEntries' -Tag 'Unit' {

    Context 'Function Availability' {
        It 'Should exist in the module' {
            Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have defined parameters' {
            $cmd = Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName
            $cmd.Parameters.Count | Should -BeGreaterThan 0
        }

        It 'Should have ComputerName parameter' {
            $cmd = Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName
            $cmd.Parameters.ContainsKey('ComputerName') | Should -Be $true
        }

        It 'Should have ComputerName as mandatory parameter' {
            $cmd = Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName
            $cmd.Parameters['ComputerName'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It 'Should have ZoneName parameter' {
            $cmd = Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName
            $cmd.Parameters.ContainsKey('ZoneName') | Should -Be $true
        }

        It 'Should have Credential parameter' {
            $cmd = Get-Command -Name Find-DnsDuplicateEntries -Module $script:moduleName
            $cmd.Parameters.ContainsKey('Credential') | Should -Be $true
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Find-DnsDuplicateEntries -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have synopsis' {
            $help = Get-Help -Name Find-DnsDuplicateEntries -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help -Name Find-DnsDuplicateEntries -ErrorAction SilentlyContinue
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Find-DnsDuplicateEntries -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }
}
