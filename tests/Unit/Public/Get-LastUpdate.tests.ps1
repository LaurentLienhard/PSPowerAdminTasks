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

Describe 'Get-LastUpdate' -Tag 'Unit' {

    Context 'Function Availability' {
        It 'Should exist in the module' {
            Get-Command -Name Get-LastUpdate -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-LastUpdate -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {
        
        It 'Should have ComputerName parameter' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.Parameters.ContainsKey('ComputerName') | Should -Be $true
        }

        It 'Should have OnlySupported switch parameter' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.Parameters.ContainsKey('OnlySupported') | Should -Be $true
        }

        It 'Should have UploadToGDriveParams parameter' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.Parameters.ContainsKey('UploadToGDriveParams') | Should -Be $true
        }

        It 'Should have SendByMail switch parameter' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.Parameters.ContainsKey('SendByMail') | Should -Be $true
        }

        It 'Should have Credential parameter' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.Parameters.ContainsKey('Credential') | Should -Be $true
        }
    }

    Context 'Parameter Sets' {
        
        It 'Should have ByComputerName parameter set' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.ParameterSets | Where-Object { $_.Name -eq 'ByComputerName' } | Should -Not -BeNullOrEmpty
        }

        It 'Should have OnlySupported parameter set' {
            $cmd = Get-Command -Name Get-LastUpdate -Module $script:moduleName
            $cmd.ParameterSets | Where-Object { $_.Name -eq 'OnlySupported' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {
        
        It 'Should have help documentation' {
            $help = Get-Help -Name Get-LastUpdate -ErrorAction SilentlyContinue
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have parameter help' {
            $help = Get-Help -Name Get-LastUpdate -ErrorAction SilentlyContinue
            $help.Parameters.parameter | Should -Not -BeNullOrEmpty
        }
    }
}
