BeforeAll {
    # Find the module path by going up from the test directory
    $testDir = $PSScriptRoot
    $projectRoot = Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $testDir)))

    $modulePath = Join-Path -Path $projectRoot -ChildPath 'output\module\PSPowerAdminTasks'
    if (-not (Test-Path -Path $modulePath)) {
        $modulePath = Join-Path -Path $projectRoot -ChildPath 'source'
    }

    Import-Module -Name $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name PSPowerAdminTasks -Force -ErrorAction SilentlyContinue
}

Describe 'Get-DirectoryTree' {
    Context 'Parameter validation' {
        It 'Should require Path parameter' {
            { Get-DirectoryTree } | Should -Throw
        }

        It 'Should accept valid ItemType: Both' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }
            { Get-DirectoryTree -Path 'TestPath' -ItemType 'Both' -Depth 0 } | Should -Not -Throw
        }

        It 'Should accept valid ItemType: Files' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }
            { Get-DirectoryTree -Path 'TestPath' -ItemType 'Files' -Depth 0 } | Should -Not -Throw
        }

        It 'Should accept valid ItemType: Directories' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }
            { Get-DirectoryTree -Path 'TestPath' -ItemType 'Directories' -Depth 0 } | Should -Not -Throw
        }

        It 'Should reject invalid ItemType' {
            { Get-DirectoryTree -Path 'TestPath' -ItemType 'Invalid' } | Should -Throw
        }

        It 'Should accept Depth parameter' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }
            { Get-DirectoryTree -Path 'TestPath' -Depth 5 } | Should -Not -Throw
        }

        It 'Should accept -1 for unlimited depth' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }
            { Get-DirectoryTree -Path 'TestPath' -Depth -1 } | Should -Not -Throw
        }

        It 'Should reject invalid Depth values' {
            { Get-DirectoryTree -Path 'TestPath' -Depth -2 } | Should -Throw
        }
    }

    Context 'Local path processing' {
        It 'Should return error for non-existent path' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                throw 'Path not found'
            }
            { Get-DirectoryTree -Path 'NonExistent' -ErrorAction Stop } | Should -Throw
        }

        It 'Should return object with required properties' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'Name'
            $result[0].PSObject.Properties.Name | Should -Contain 'FullName'
            $result[0].PSObject.Properties.Name | Should -Contain 'Type'
            $result[0].PSObject.Properties.Name | Should -Contain 'Size'
            $result[0].PSObject.Properties.Name | Should -Contain 'Depth'
            $result[0].PSObject.Properties.Name | Should -Contain 'LastWriteTime'
        }

        It 'Should return correct Type values for files' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result.Type | Should -Be 'File'
        }

        It 'Should return correct Type values for directories' {
            $mockDir = New-Object PSObject -Property @{
                Name            = 'testdir'
                FullName        = '/path/testdir'
                PSIsContainer   = $true
                Length          = 0
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockDir)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result.Type | Should -Be 'Directory'
        }

        It 'Should return Size as integer' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 2048
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result.Size | Should -BeOfType [long]
            $result.Size | Should -Be 2048
        }

        It 'Should include correct Depth information' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 1
            $result.Depth | Should -Be 1
        }

        It 'Should filter by ItemType: Files only' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            $mockDir = New-Object PSObject -Property @{
                Name            = 'testdir'
                FullName        = '/path/testdir'
                PSIsContainer   = $true
                Length          = 0
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile, $mockDir)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0 -ItemType Files
            @($result).ForEach({ $_.Type | Should -Be 'File' })
        }

        It 'Should filter by ItemType: Directories only' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            $mockDir = New-Object PSObject -Property @{
                Name            = 'testdir'
                FullName        = '/path/testdir'
                PSIsContainer   = $true
                Length          = 0
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile, $mockDir)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0 -ItemType Directories
            @($result).ForEach({ $_.Type | Should -Be 'Directory' })
        }

        It 'Should handle empty directory' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -BeNullOrEmpty
        }

        It 'Should handle multiple items' {
            $mockFile1 = New-Object PSObject -Property @{
                Name            = 'file1.txt'
                FullName        = '/path/file1.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            $mockFile2 = New-Object PSObject -Property @{
                Name            = 'file2.txt'
                FullName        = '/path/file2.txt'
                PSIsContainer   = $false
                Length          = 2048
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile1, $mockFile2)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            @($result).Count | Should -Be 2
        }
    }

    Context 'Recursion and Depth handling' {
        It 'Should respect Depth limit' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result.Depth | Should -Be 0
        }

        It 'Should handle Depth 0' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'WhatIf support' {
        It 'Should support -WhatIf parameter' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            { Get-DirectoryTree -Path 'TestPath' -Depth 0 -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Pipeline support' {
        It 'Should accept Path via pipeline' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            { 'TestPath' | Get-DirectoryTree -Depth 0 } | Should -Not -Throw
        }
    }

    Context 'Default parameter values' {
        It 'Should use default Depth of 3' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            { Get-DirectoryTree -Path 'TestPath' } | Should -Not -Throw
        }

        It 'Should use default ItemType of Both' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            $mockDir = New-Object PSObject -Property @{
                Name            = 'testdir'
                FullName        = '/path/testdir'
                PSIsContainer   = $true
                Length          = 0
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile, $mockDir)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
        }
    }

    Context 'Output format' {
        It 'Should return PSCustomObject' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -BeOfType [System.Management.Automation.PSCustomObject]
        }

        It 'Should have consistent property types' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockFile)
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result.Name | Should -BeOfType [string]
            $result.FullName | Should -BeOfType [string]
            $result.Type | Should -BeOfType [string]
            $result.Size | Should -BeOfType [long]
            $result.Depth | Should -BeOfType [int]
        }
    }

    Context 'Cross-platform compatibility' {
        It 'Should handle Windows-style paths' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            { Get-DirectoryTree -Path 'C:\Users\Test' -Depth 0 } | Should -Not -Throw
        }

        It 'Should handle Unix-style paths' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            { Get-DirectoryTree -Path '/home/user' -Depth 0 } | Should -Not -Throw
        }
    }

    Context 'Error handling' {
        It 'Should handle access denied errors' {
            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                throw 'Access is denied'
            }

            { Get-DirectoryTree -Path 'RestrictedPath' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should handle get-childitem returning single object' {
            $mockFile = New-Object PSObject -Property @{
                Name            = 'testfile.txt'
                FullName        = '/path/testfile.txt'
                PSIsContainer   = $false
                Length          = 1024
                LastWriteTime   = [datetime]'2025-01-21 10:00:00'
            }

            Mock -CommandName Get-ChildItem -ModuleName PSPowerAdminTasks -MockWith {
                return $mockFile
            }

            $result = Get-DirectoryTree -Path 'TestPath' -Depth 0
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
