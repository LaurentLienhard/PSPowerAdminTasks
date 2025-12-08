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

Describe 'Set-RemoteDnsServer' -Tag 'Unit' {

    Context 'Parameter Acceptance' {

        It 'Should accept ComputerName parameter as string' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8', '8.8.4.4' } | Should -Not -Throw
        }

        It 'Should accept ComputerName as array' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01', 'PC02' -ServerAddresses '8.8.8.8' } | Should -Not -Throw
        }

        It 'Should accept ComputerName from pipeline' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { 'PC01' | Set-RemoteDnsServer -ServerAddresses '8.8.8.8' } | Should -Not -Throw
        }

        It 'Should accept Credential parameter' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -MockWith { $null }
            $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Credential $cred } | Should -Not -Throw
        }

        It 'Should require ServerAddresses for All parameter set' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ErrorAction Stop } | Should -Throw
        }

        It 'Should require OldAddress and NewAddress for Replace parameter set' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -OldAddress '192.168.1.1' -ErrorAction Stop } | Should -Throw
            { Set-RemoteDnsServer -ComputerName 'PC01' -NewAddress '1.1.1.1' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'ParameterSet: All - Modern Method (NetAdapter)' {

        It 'Should invoke Invoke-Command for each computer' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01', 'PC02' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2
        }

        It 'Should pass correct ComputerName to Invoke-Command' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ComputerName -eq 'PC01' } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ComputerName -eq 'PC01' } -Times 1
        }

        It 'Should use ScriptBlock for remote execution' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -Times 1
        }

        It 'Should pass ErrorAction Stop to Invoke-Command' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ErrorAction -eq 'Stop' } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ErrorAction -eq 'Stop' } -Times 1
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }
            $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Credential $cred

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -Times 1
        }

        It 'Should not pass Credential when not provided' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -eq $Credential } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1
        }

        It 'Should handle multiple DNS server addresses' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8', '8.8.4.4', '1.1.1.1' } | Should -Not -Throw
        }

        It 'Should output verbose message on successful operation' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            $verbose = Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Verbose 4>&1

            # Check for verbose output messages
            $verbose | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ParameterSet: Replace - Modern Method (NetAdapter)' {

        It 'Should invoke Invoke-Command with Replace parameter set' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -OldAddress '192.168.1.1' -NewAddress '1.1.1.1'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1
        }

        It 'Should pass correct parameters for Replace parameter set' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -OldAddress '192.168.1.1' -NewAddress '1.1.1.1'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -Times 1
        }

        It 'Should handle multiple computers with Replace parameter set' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01', 'PC02', 'PC03' -OldAddress '192.168.1.1' -NewAddress '1.1.1.1'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 3
        }
    }

    Context 'Pipeline Input' {

        It 'Should accept computer names from pipeline' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { 'PC01', 'PC02' | Set-RemoteDnsServer -ServerAddresses '8.8.8.8' } | Should -Not -Throw
        }

        It 'Should process each computer from pipeline' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            @('PC01', 'PC02', 'PC03') | ForEach-Object { Set-RemoteDnsServer -ComputerName $_ -ServerAddresses '8.8.8.8' }

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 3
        }
    }

    Context 'Error Handling' {

        It 'Should catch and warn when Invoke-Command fails' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { throw 'Connection failed' }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue -WarningVariable warn 2>&1

            $warn | Should -Not -BeNullOrEmpty
        }

        It 'Should continue processing other computers on failure' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                if ($ComputerName -eq 'PC01') {
                    throw 'Connection failed'
                }
            }

            Set-RemoteDnsServer -ComputerName 'PC01', 'PC02' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2
        }

        It 'Should handle error message in exception' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { throw 'Network timeout' }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue -WarningVariable warn 2>&1

            $warn[0] | Should -Match 'Network timeout'
        }

        It 'Should handle exception gracefully' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { throw [System.Exception]'Remote operation failed' }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Verbose Output' {

        It 'Should output verbose messages when processing' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            $verboseOutput = Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Verbose 4>&1

            $verboseOutput | Should -Not -BeNullOrEmpty
        }

        It 'Should include computer name in verbose messages' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            $verboseOutput = Set-RemoteDnsServer -ComputerName 'TESTPC' -ServerAddresses '8.8.8.8' -Verbose 4>&1

            [string]$verboseString = $verboseOutput -join ' '
            $verboseString | Should -Match 'TESTPC'
        }

        It 'Should output verbose message on successful completion' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            $verboseOutput = Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Verbose 4>&1

            [string]$verboseString = $verboseOutput -join ' '
            $verboseString | Should -Match 'successfully|completed'
        }
    }

    Context 'Credential Handling' {

        It 'Should pass credential to Invoke-Command' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'testpass' -AsPlainText -Force))

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Credential $cred

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -Times 1
        }

        It 'Should work with default credentials when not specified' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $PSBoundParameters.ContainsKey('Credential') -eq $false } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1
        }
    }

    Context 'Parameter Combinations' {

        It 'Should handle All parameter set with multiple addresses' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8', '8.8.4.4', '1.1.1.1', '1.0.0.1' } | Should -Not -Throw
        }

        It 'Should not mix parameter sets' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -OldAddress '192.168.1.1' -ErrorAction Stop } | Should -Throw
        }

        It 'Should handle Replace with new address only' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -OldAddress '192.168.1.1' -NewAddress '1.1.1.1' } | Should -Not -Throw
        }
    }

    Context 'Script Block Behavior' {

        It 'Should pass script block to Invoke-Command' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $null -ne $ScriptBlock } -Times 1
        }

        It 'Should handle script block with modern method detection' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' } | Should -Not -Throw
        }
    }

    Context 'Multiple Computer Processing' {

        It 'Should process all computers sequentially' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01', 'PC02', 'PC03' -ServerAddresses '8.8.8.8'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 3
        }

        It 'Should handle failure on one computer without stopping others' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ComputerName -eq 'PC02' } -MockWith { throw 'Failed' }
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter { $ComputerName -ne 'PC02' } -MockWith { $null }

            Set-RemoteDnsServer -ComputerName 'PC01', 'PC02', 'PC03' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 3
        }
    }

    Context 'Help Documentation' {

        It 'Should have help for ComputerName parameter' {
            $help = Get-Help Set-RemoteDnsServer -Parameter ComputerName
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have help for ServerAddresses parameter' {
            $help = Get-Help Set-RemoteDnsServer -Parameter ServerAddresses
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have help for OldAddress parameter' {
            $help = Get-Help Set-RemoteDnsServer -Parameter OldAddress
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have help for NewAddress parameter' {
            $help = Get-Help Set-RemoteDnsServer -Parameter NewAddress
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have help for Credential parameter' {
            $help = Get-Help Set-RemoteDnsServer -Parameter Credential
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have synopsis' {
            $help = Get-Help Set-RemoteDnsServer
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Set-RemoteDnsServer
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Set-RemoteDnsServer
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CmdletBinding Features' {

        It 'Should support -Verbose parameter' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -Verbose } | Should -Not -Throw
        }

        It 'Should support -WarningAction parameter' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should support -ErrorAction parameter' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith { $null }

            { Set-RemoteDnsServer -ComputerName 'PC01' -ServerAddresses '8.8.8.8' -ErrorAction Stop } | Should -Not -Throw
        }
    }

}
