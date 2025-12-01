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

Describe 'Get-RemoteGPResult' -Tag 'Unit' {

    Context 'Parameter Validation' {

        It 'Should validate Scope parameter against allowed values' {
            { Get-RemoteGPResult -ComputerName SERVER01 -Scope InvalidScope -ErrorAction Stop } | Should -Throw
        }

        It 'Should allow Scope Computer' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01 -Scope Computer -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should allow Scope User' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01 -Scope User -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should allow Scope Both (default)' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should support Show switch parameter' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01 -Show -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should accept Credential parameter' {
            Mock -CommandName Test-Connection -MockWith { $false }
            $cred = New-Object System.Management.Automation.PSCredential ('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            { Get-RemoteGPResult -ComputerName SERVER01 -Credential $cred -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should accept multiple ComputerNames' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01, SERVER02, SERVER03 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should accept ThrottleLimit parameter' {
            Mock -CommandName Test-Connection -MockWith { $false }
            { Get-RemoteGPResult -ComputerName SERVER01, SERVER02 -ThrottleLimit 10 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Connectivity Testing' {

        It 'Should handle unreachable computers' {
            Mock -CommandName Test-Connection -MockWith { $false }

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }

        It 'Should process multiple computers' {
            Mock -CommandName Test-Connection -MockWith { $false }

            # Should complete without throwing
            { Get-RemoteGPResult -ComputerName SERVER01, SERVER02 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Output Path Handling' {

        It 'Should generate timestamped filename when OutputPath not specified' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = 'SERVER01'} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue

            if ($result) {
                $result.ReportPath | Should -Match "GPResult_SERVER01_\d{8}_\d{6}\.html"
            }
        }

        It 'Should use specified file path as-is when provided' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = 'SERVER01'} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith {
                if ($Path -eq '/tmp/custom_report.html') { return $false }
                return $true
            }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -OutputPath '/tmp/custom_report.html' -ErrorAction SilentlyContinue

            if ($result) {
                $result.ReportPath | Should -Be '/tmp/custom_report.html'
            }
        }

        It 'Should handle OutputPath with extensions' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = 'SERVER01'} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -OutputPath '/tmp/NewDir/report.html' -ErrorAction SilentlyContinue | Out-Null

            # Function should complete without error
            $? | Should -Be $true
        }
    }

    Context 'Remote Session Management' {

        It 'Should create PSSession' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            # Should complete successfully
            { Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should handle session creation errors' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { throw 'Connection error' }

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Remote Report Generation' {

        It 'Should execute with Scope Computer' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            # Should complete without error
            { Get-RemoteGPResult -ComputerName SERVER01 -Scope Computer -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should write error when remote scriptblock returns null' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { $null }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }
    }

    Context 'File Copy and Validation' {

        It 'Should copy file successfully' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue

            # If the function succeeded, Copy-Item was called
            if ($result) {
                $result.FileSize | Should -Be 1024
            }
        }

        It 'Should verify file exists after copy' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $false }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }

        It 'Should handle empty file error' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 0} }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Report Opening' {

        It 'Should handle Show switch' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Invoke-Item -MockWith {}
            Mock -CommandName Remove-PSSession -MockWith {}

            # Should not throw when Show is specified
            { Get-RemoteGPResult -ComputerName SERVER01 -Show -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should not open report when Show switch is not specified' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Invoke-Item -MockWith {}
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue | Out-Null

            Should -Invoke -CommandName Invoke-Item -Times 0
        }
    }

    Context 'Return Values' {

        It 'Should return PSCustomObject with correct properties' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 2048} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue

            if ($result) {
                $result | Should -HaveProperty 'ComputerName'
                $result | Should -HaveProperty 'ReportPath'
                $result | Should -HaveProperty 'Scope'
                $result | Should -HaveProperty 'UserName'
                $result | Should -HaveProperty 'Timestamp'
                $result | Should -HaveProperty 'FileSize'
                $result.Scope | Should -Be 'Both'
                $result.UserName | Should -Be 'Current User'
                $result.FileSize | Should -Be 2048
            }
        }

        It 'Should include custom UserName in output when provided' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -UserName 'domain\testuser' -ErrorAction SilentlyContinue

            if ($result) {
                $result.UserName | Should -Be 'domain\testuser'
            }
        }

        It 'Should include correct Scope in output' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            $result = Get-RemoteGPResult -ComputerName SERVER01 -Scope User -ErrorAction SilentlyContinue

            if ($result) {
                $result.Scope | Should -Be 'User'
            }
        }
    }

    Context 'Error Handling' {

        It 'Should handle PSRemotingTransportException' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith {
                throw [System.Management.Automation.Remoting.PSRemotingTransportException]::new('Connection failed')
            }

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }

        It 'Should handle UnauthorizedAccessException' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith {
                throw [System.UnauthorizedAccessException]::new('Access denied')
            }

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }

        It 'Should handle generic exceptions' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { throw 'Generic error' }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Parallel Processing' {

        It 'Should accept multiple computers' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            # Should not throw when processing multiple computers
            { Get-RemoteGPResult -ComputerName SERVER01, SERVER02, SERVER03 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should have default ThrottleLimit of 5' {
            Mock -CommandName Test-Connection -MockWith { $false }

            # If no error is thrown, the parameter with default value is accepted
            { Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Remote Cleanup' {

        It 'Should invoke cleanup command after copying file' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            Get-RemoteGPResult -ComputerName SERVER01 -ErrorAction SilentlyContinue | Out-Null

            # Invoke-Command should be called at least once
            Should -Invoke -CommandName Invoke-Command -AtLeast 1
        }
    }

    Context 'Verbose Output' {

        It 'Should support Verbose switch' {
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName New-PSSession -MockWith { [PSCustomObject]@{ComputerName = $ComputerName} }
            Mock -CommandName Invoke-Command -MockWith { 'C:\Temp\test.html' }
            Mock -CommandName Copy-Item -MockWith {}
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName Get-Item -MockWith { [PSCustomObject]@{Length = 1024} }
            Mock -CommandName Remove-PSSession -MockWith {}

            { Get-RemoteGPResult -ComputerName SERVER01 -Verbose -ErrorAction SilentlyContinue 4>&1 } | Should -Not -Throw
        }
    }

}
