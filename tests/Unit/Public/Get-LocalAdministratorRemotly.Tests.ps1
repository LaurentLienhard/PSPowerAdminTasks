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

Describe 'Get-LocalAdministratorsRemotly' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a mandatory ComputerName parameter' {
            $param = (Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName).Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have an optional Credential parameter' {
            $param = (Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName).Parameters['Credential']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have a Log switch parameter' {
            $param = (Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName).Parameters['log']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }

        It 'Should have a LogPath parameter' {
            $param = (Get-Command -Name Get-LocalAdministratorsRemotly -Module $script:moduleName).Parameters['LogPath']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Get-LocalAdministratorsRemotly -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Get-LocalAdministratorsRemotly -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Get-LocalAdministratorsRemotly -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - Success Path' {

        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    ComputerName    = 'SERVER01'
                    OSVersion       = 'Windows Server 2019'
                    Member          = 'DOMAIN\AdminUser'
                    ObjectClass     = 'User'
                    PrincipalSource = 'ActiveDirectory'
                }
            }

            Mock -CommandName Write-Log -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call Invoke-Command for each computer' {
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01'
            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should return a result for each computer' {
            $result = Get-LocalAdministratorsRemotly -ComputerName 'SERVER01'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should call Invoke-Command for each computer in a list' {
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01', 'SERVER02'
            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2 -Exactly
        }
    }

    Context 'Execution - With Log Switch' {

        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    ComputerName    = 'SERVER01'
                    OSVersion       = 'Windows Server 2019'
                    Member          = 'DOMAIN\AdminUser'
                    ObjectClass     = 'User'
                    PrincipalSource = 'ActiveDirectory'
                }
            }

            Mock -CommandName Write-Log -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call Write-Log when -log switch is specified' {
            Get-LocalAdministratorsRemotly -ComputerName 'SERVER01' -log
            Should -Invoke -CommandName Write-Log -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }

    Context 'Execution - Error Path' {

        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                throw 'Connection refused'
            }
        }

        It 'Should return a failed object on connection error' {
            $result = Get-LocalAdministratorsRemotly -ComputerName 'SERVER01'
            $result | Should -Not -BeNullOrEmpty
            $result.ComputerName | Should -Be 'SERVER01'
        }
    }
}
