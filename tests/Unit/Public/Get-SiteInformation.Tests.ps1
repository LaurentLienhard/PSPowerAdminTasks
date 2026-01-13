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

Describe 'Get-SiteInformation' -Tag 'Unit' {

    Context 'Function Availability' {
        It 'Should exist in the module' {
            Get-Command -Name Get-SiteInformation -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-SiteInformation -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {
        
        It 'Should have defined parameters' {
            $cmd = Get-Command -Name Get-SiteInformation -Module $script:moduleName
            $cmd.Parameters.Count | Should -BeGreaterThan 0
        }

        It 'Should have parameter sets' {
            $cmd = Get-Command -Name Get-SiteInformation -Module $script:moduleName
            $cmd.ParameterSets | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {
        
        It 'Should have help documentation' {
            $help = Get-Help -Name Get-SiteInformation -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have synopsis' {
            $help = Get-Help -Name Get-SiteInformation -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }
}
