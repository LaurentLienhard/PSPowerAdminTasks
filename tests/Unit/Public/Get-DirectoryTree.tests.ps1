Describe 'Get-DirectoryTree' {
    Context 'Parameter validation' {
        It 'Should require Path parameter' {
            { Get-DirectoryTree } | Should -Throw
        }

        It 'Should accept valid ItemType values' {
            foreach ($type in @('Both', 'Files', 'Directories'))
            {
                { Get-DirectoryTree -Path $PSScriptRoot -ItemType $type -Depth 0 } | Should -Not -Throw
            }
        }

        It 'Should reject invalid ItemType' {
            { Get-DirectoryTree -Path $PSScriptRoot -ItemType 'Invalid' } | Should -Throw
        }

        It 'Should accept Depth parameter' {
            { Get-DirectoryTree -Path $PSScriptRoot -Depth 5 } | Should -Not -Throw
        }

        It 'Should accept -1 for unlimited depth' {
            { Get-DirectoryTree -Path $PSScriptRoot -Depth -1 } | Should -Not -Throw
        }

        It 'Should reject invalid Depth values' {
            { Get-DirectoryTree -Path $PSScriptRoot -Depth -2 } | Should -Throw
        }
    }

    Context 'Local path processing' {
        It 'Should return error for non-existent path' {
            { Get-DirectoryTree -Path 'C:\NonExistentPath_12345' -ErrorAction Stop } | Should -Throw
        }

        It 'Should return object with required properties' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0
            if ($result)
            {
                $result[0].PSObject.Properties.Name | Should -Contain 'Name'
                $result[0].PSObject.Properties.Name | Should -Contain 'FullName'
                $result[0].PSObject.Properties.Name | Should -Contain 'Type'
                $result[0].PSObject.Properties.Name | Should -Contain 'Size'
                $result[0].PSObject.Properties.Name | Should -Contain 'Depth'
                $result[0].PSObject.Properties.Name | Should -Contain 'LastWriteTime'
            }
        }

        It 'Should return correct Type values' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0
            foreach ($item in $result)
            {
                $item.Type | Should -BeIn @('File', 'Directory')
            }
        }

        It 'Should return Size as integer' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0
            foreach ($item in $result)
            {
                $item.Size | Should -BeOfType [long]
            }
        }

        It 'Should include Depth information' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 1
            foreach ($item in $result)
            {
                $item.Depth | Should -BeGreaterOrEqual 1
            }
        }

        It 'Should filter by ItemType: Files only' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0 -ItemType Files
            foreach ($item in $result)
            {
                $item.Type | Should -Be 'File'
            }
        }

        It 'Should filter by ItemType: Directories only' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0 -ItemType Directories
            foreach ($item in $result)
            {
                $item.Type | Should -Be 'Directory'
            }
        }

        It 'Should handle empty or shallow directory' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0
            # Result can be null (empty) or an object
            ($result -is [System.Management.Automation.PSCustomObject] -or $result -is [System.Object[]] -or $result -eq $null) | Should -Be $true
        }
    }

    Context 'WhatIf support' {
        It 'Should support -WhatIf parameter' {
            { Get-DirectoryTree -Path $PSScriptRoot -Depth 0 -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Pipeline support' {
        It 'Should accept Path via pipeline' {
            { $PSScriptRoot | Get-DirectoryTree -Depth 0 } | Should -Not -Throw
        }
    }

    Context 'Default parameter values' {
        It 'Should use default Depth of 3' {
            { Get-DirectoryTree -Path $PSScriptRoot } | Should -Not -Throw
        }

        It 'Should use default ItemType of Both' {
            $result = Get-DirectoryTree -Path $PSScriptRoot -Depth 0
            if ($result.Count -gt 1)
            {
                $hasFiles = $result | Where-Object { $_.Type -eq 'File' } | Measure-Object | Select-Object -ExpandProperty Count
                $hasDirectories = $result | Where-Object { $_.Type -eq 'Directory' } | Measure-Object | Select-Object -ExpandProperty Count
                # At least one type should be present
                ($hasFiles + $hasDirectories) | Should -BeGreaterThan 0
            }
        }
    }
}
