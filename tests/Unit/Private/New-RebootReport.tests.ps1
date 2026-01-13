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

Describe 'New-RebootReport' -Tag 'Unit' {

    Context 'Function Availability' {
        It 'Should module loads without errors' {
            Get-Module -Name $script:moduleName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Module Contents' {
        It 'Should have functions' {
            (Get-Command -Module $script:moduleName -CommandType Function).Count | Should -BeGreaterThan 0
        }

        It 'Should have exported functions' {
            (Get-Command -Module $script:moduleName).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Module Properties' {
        It 'Should have proper version' {
            (Get-Module -Name $script:moduleName).Version | Should -Not -BeNullOrEmpty
        }

        It 'Should be loaded correctly' {
            (Get-Module -Name $script:moduleName).Name | Should -Be $script:moduleName
        }
    }
}
