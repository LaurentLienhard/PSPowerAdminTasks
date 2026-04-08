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

Describe 'Start-RebootServerByGroup' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Start-RebootServerByGroup -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Start-RebootServerByGroup -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a Log switch parameter' {
            $param = (Get-Command -Name Start-RebootServerByGroup -Module $script:moduleName).Parameters['Log']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }

        It 'Should support ShouldProcess (WhatIf)' {
            $cmd = Get-Command -Name Start-RebootServerByGroup -Module $script:moduleName
            $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Start-RebootServerByGroup -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Start-RebootServerByGroup -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - WhatIf (No Actual Reboot)' {

        BeforeAll {
            Mock -CommandName Get-ADGroup -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Name = 'WSUS-Servers-2012' }
            }

            Mock -CommandName Get-ADGroupMember -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        distinguishedName = 'CN=SRV2012-01,OU=Servers,DC=domain,DC=local'
                        objectClass       = 'computer'
                    }
                )
            }

            Mock -CommandName Get-ADComputer -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name            = 'SRV2012-01'
                    OperatingSystem = 'Windows Server 2012 R2 Standard'
                }
            }

            Mock -CommandName Restart-Computer -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Write-Host -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should not call Restart-Computer when -WhatIf is specified' {
            Start-RebootServerByGroup -WSUSGroupName 'WSUS-Servers-2012' -WhatIf
            Should -Invoke -CommandName Restart-Computer -ModuleName $script:moduleName -Times 0 -Exactly
        }
    }

    Context 'Execution - OS Filter' {

        BeforeAll {
            Mock -CommandName Get-ADGroup -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Name = 'WSUS-Servers-2019' }
            }

            Mock -CommandName Get-ADGroupMember -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        distinguishedName = 'CN=SRV2019-01,OU=Servers,DC=domain,DC=local'
                        objectClass       = 'computer'
                    }
                )
            }

            Mock -CommandName Get-ADComputer -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name            = 'SRV2019-01'
                    OperatingSystem = 'Windows Server 2019 Standard'
                }
            }

            Mock -CommandName Restart-Computer -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Write-Host -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should not reboot servers with OS not matching 2003/2008/2012' {
            Start-RebootServerByGroup -WSUSGroupName 'WSUS-Servers-2019' -Confirm:$false
            Should -Invoke -CommandName Restart-Computer -ModuleName $script:moduleName -Times 0 -Exactly
        }
    }

    Context 'Execution - Successful Reboot' {

        BeforeAll {
            Mock -CommandName Get-ADGroup -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Name = 'WSUS-Servers-2012' }
            }

            Mock -CommandName Get-ADGroupMember -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        distinguishedName = 'CN=SRV2012-01,OU=Servers,DC=domain,DC=local'
                        objectClass       = 'computer'
                    }
                )
            }

            Mock -CommandName Get-ADComputer -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name            = 'SRV2012-01'
                    OperatingSystem = 'Windows Server 2012 R2 Standard'
                }
            }

            Mock -CommandName Restart-Computer -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Write-Host -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call Restart-Computer for a matching server' {
            Start-RebootServerByGroup -WSUSGroupName 'WSUS-Servers-2012' -Confirm:$false
            Should -Invoke -CommandName Restart-Computer -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }
}
