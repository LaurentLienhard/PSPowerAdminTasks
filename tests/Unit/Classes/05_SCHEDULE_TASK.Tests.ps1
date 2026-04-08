BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    $modulePath = "$PSScriptRoot/../../../output/module/$script:moduleName"
    if (-not (Test-Path $modulePath)) {
        $modulePath = "$PSScriptRoot/../../../source"
    }

    $script:module = Import-Module (Join-Path $modulePath "$script:moduleName.psd1") -Force -ErrorAction Stop -PassThru
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'ScheduleTask Class' -Tag 'Unit' {

    Context 'Constructor - Default (Empty)' {

        It 'Should create an instance without throwing' {
            { & (Get-Module $script:moduleName) { [ScheduleTask]::new() } } | Should -Not -Throw
        }

        It 'Should initialize ComputerName as null or empty' {
            $task = & (Get-Module $script:moduleName) { [ScheduleTask]::new() }
            $task.ComputerName | Should -BeNullOrEmpty
        }

        It 'Should initialize TaskName as null or empty' {
            $task = & (Get-Module $script:moduleName) { [ScheduleTask]::new() }
            $task.TaskName | Should -BeNullOrEmpty
        }

        It 'Should initialize LastRunTime as null (Nullable DateTime)' {
            $task = & (Get-Module $script:moduleName) { [ScheduleTask]::new() }
            $task.LastRunTime | Should -BeNullOrEmpty
        }

        It 'Should initialize NextRunTime as null (Nullable DateTime)' {
            $task = & (Get-Module $script:moduleName) { [ScheduleTask]::new() }
            $task.NextRunTime | Should -BeNullOrEmpty
        }
    }

    Context 'Property Assignment' {

        It 'Should accept a string value for ComputerName' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.ComputerName = 'SERVER01'
                $t
            }
            $task.ComputerName | Should -Be 'SERVER01'
        }

        It 'Should accept a string value for TaskName' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.TaskName = 'MyDailyBackup'
                $t
            }
            $task.TaskName | Should -Be 'MyDailyBackup'
        }

        It 'Should accept a string value for TaskPath' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.TaskPath = '\Microsoft\Windows\'
                $t
            }
            $task.TaskPath | Should -Be '\Microsoft\Windows\'
        }

        It 'Should accept a string value for State' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.State = 'Ready'
                $t
            }
            $task.State | Should -Be 'Ready'
        }

        It 'Should accept a string value for Author' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.Author = 'NT AUTHORITY\SYSTEM'
                $t
            }
            $task.Author | Should -Be 'NT AUTHORITY\SYSTEM'
        }

        It 'Should accept a string value for RunAsUser' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.RunAsUser = 'DOMAIN\ServiceAccount'
                $t
            }
            $task.RunAsUser | Should -Be 'DOMAIN\ServiceAccount'
        }

        It 'Should accept a DateTime for LastRunTime' {
            $expectedDate = [datetime]'2025-01-15 08:00:00'
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.LastRunTime = [datetime]'2025-01-15 08:00:00'
                $t
            }
            $task.LastRunTime | Should -Be $expectedDate
        }

        It 'Should accept a string value for LastTaskResult' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.LastTaskResult = '0'
                $t
            }
            $task.LastTaskResult | Should -Be '0'
        }
    }

    Context 'Full Object Population' {

        It 'Should store all properties correctly when fully populated' {
            $task = & (Get-Module $script:moduleName) {
                $t = [ScheduleTask]::new()
                $t.ComputerName   = 'SRV01'
                $t.TaskName       = 'BackupTask'
                $t.TaskPath       = '\'
                $t.State          = 'Ready'
                $t.Author         = 'SYSTEM'
                $t.RunAsUser      = 'NT AUTHORITY\SYSTEM'
                $t.LastRunTime    = [datetime]'2025-03-01 02:00:00'
                $t.NextRunTime    = [datetime]'2025-03-02 02:00:00'
                $t.LastTaskResult = '0'
                $t
            }
            $task.ComputerName   | Should -Be 'SRV01'
            $task.TaskName       | Should -Be 'BackupTask'
            $task.TaskPath       | Should -Be '\'
            $task.State          | Should -Be 'Ready'
            $task.Author         | Should -Be 'SYSTEM'
            $task.RunAsUser      | Should -Be 'NT AUTHORITY\SYSTEM'
            $task.LastTaskResult | Should -Be '0'
        }
    }
}
