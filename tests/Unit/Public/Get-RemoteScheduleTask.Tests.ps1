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
}
