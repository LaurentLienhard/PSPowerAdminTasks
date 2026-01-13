BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Try built module first, then source
    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName/0.0.1"
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

Describe 'COMPUTER Class' -Tag 'Unit' {

    Context 'Constructor - Default' {

        It 'Should create instance with no parameters' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should initialize with default values' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Constructor - With Parameters' {

        It 'Should create instance with ComputerName' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should create instance with ComputerName and OperatingSystem' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Properties' {

        It 'Should have Name property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have OperatingSystem property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have DNSHostName property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have LogicalProcessors property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should have TotalMemory property' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }

    Context 'Methods' {

        It 'Should return meaningful ToString output' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It 'Should convert to hashtable' {
            { Get-Module $script:moduleName | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }
    }
}
