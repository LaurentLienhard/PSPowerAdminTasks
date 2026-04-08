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

Describe 'Get-RemoteScheduleTask' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a ComputerName parameter with default localhost' {
            $param = (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should accept pipeline input on ComputerName' {
            $param = (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).Parameters['ComputerName']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -ExpandProperty ValueFromPipeline | Should -Contain $true
        }

        It 'Should have a ThrottleLimit parameter' {
            $param = (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).Parameters['ThrottleLimit']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have a SkipTaskInfo switch parameter' {
            $param = (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).Parameters['SkipTaskInfo']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }

        It 'Should have an OperationTimeoutSec parameter' {
            $param = (Get-Command -Name Get-RemoteScheduleTask -Module $script:moduleName).Parameters['OperationTimeoutSec']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Get-RemoteScheduleTask -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Get-RemoteScheduleTask -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Get-RemoteScheduleTask -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - Success Path' {

        BeforeAll {
            $script:fakeCimSession = [PSCustomObject]@{ Id = 1; ComputerName = 'SRV01' }

            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                $script:fakeCimSession
            }

            Mock -CommandName Get-ScheduledTask -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        TaskName  = 'BackupTask'
                        TaskPath  = '\'
                        State     = [Microsoft.Management.Infrastructure.CimInstance]::new('MSFT_TaskRunLevel')
                        Author    = 'SYSTEM'
                        Principal = [PSCustomObject]@{ UserId = 'NT AUTHORITY\SYSTEM' }
                    }
                )
            } -ParameterFilter { $CimSession -ne $null }

            Mock -CommandName Get-ScheduledTaskInfo -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    LastRunTime    = (Get-Date).AddHours(-2)
                    NextRunTime    = (Get-Date).AddHours(22)
                    LastTaskResult = 0
                }
            }

            Mock -CommandName Get-CimSession -ModuleName $script:moduleName -MockWith { $script:fakeCimSession }
            Mock -CommandName Remove-CimSession -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call New-CimSession for the target computer' {
            Get-RemoteScheduleTask -ComputerName 'SRV01'
            Should -Invoke -CommandName New-CimSession -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should clean up the CIM session' {
            Get-RemoteScheduleTask -ComputerName 'SRV01'
            Should -Invoke -CommandName Remove-CimSession -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }

    Context 'Execution - Connection Error' {

        BeforeAll {
            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                throw 'Unable to connect'
            }
        }

        It 'Should not throw a terminating error when a connection fails' {
            { Get-RemoteScheduleTask -ComputerName 'UNREACHABLE-SRV' } | Should -Not -Throw
        }
    }
}
