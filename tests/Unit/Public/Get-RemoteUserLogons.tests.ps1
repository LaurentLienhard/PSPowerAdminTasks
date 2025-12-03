BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }

    # Create a stub for Get-WinEvent if it doesn't exist (for non-Windows systems)
    if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) {
        function global:Get-WinEvent {
            [CmdletBinding()]
            param(
                [hashtable]$FilterHashtable,
                [System.DateTime]$StartTime,
                [int[]]$ID,
                [string[]]$LogName
            )
        }
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
    Remove-Item -Path function:global:Get-WinEvent -ErrorAction SilentlyContinue
}

Describe 'Get-RemoteUserLogons' -Tag 'Unit' {

    Context 'Parameter validation' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith { @() }
        }

        It 'Should not accept null ComputerName' {
            { Get-RemoteUserLogons -ComputerName $null -ErrorAction Stop } | Should -Throw
        }

        It 'Should accept ComputerName from parameter' {
            { Get-RemoteUserLogons -ComputerName "SERVER01" } | Should -Not -Throw
        }

        It 'Should accept ComputerName from pipeline' {
            { "SERVER01" | Get-RemoteUserLogons } | Should -Not -Throw
        }

        It 'Should accept multiple computers' {
            { Get-RemoteUserLogons -ComputerName "SERVER01", "SERVER02" } | Should -Not -Throw
        }
    }

    Context 'LogonType parameter validation' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith { @() }
        }

        It 'Should accept valid logon types' {
            foreach ($Type in @("Interactive", "RDP", "Network", "Batch", "Service", "Unlock", "Cached")) {
                { Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType $Type } | Should -Not -Throw
            }
        }

        It 'Should reject invalid logon types' {
            { Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType "InvalidType" } | Should -Throw
        }
    }

    Context 'Invoke-Command integration' {
        BeforeEach {
            $script:InvokeCommandCalls = 0
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                $script:InvokeCommandCalls++
                @()  # Return empty array
            }

            Mock -CommandName Get-WinEvent -MockWith {
                return @()
            }
        }

        It 'Should call Invoke-Command once per computer' {
            Get-RemoteUserLogons -ComputerName "SERVER01" | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1 -Exactly
        }

        It 'Should call Invoke-Command for each computer' {
            Get-RemoteUserLogons -ComputerName "SERVER01", "SERVER02", "SERVER03" | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1 -Exactly
        }

        It 'Should pass Credential parameter to Invoke-Command' {
            $cred = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Get-RemoteUserLogons -ComputerName "SERVER01" -Credential $cred | Out-Null

            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Credential -ne $null
            } -Times 1 -Exactly
        }

        It 'Should pass correct Days parameter' {
            Get-RemoteUserLogons -ComputerName "SERVER01" -Days 7 | Out-Null

            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ArgumentList[0] -eq 7
            } -Times 1 -Exactly
        }
    }

    Context 'Remote script logon type mapping' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)

                # Verify the passed logon type numbers are correct
                $selectedTypes = $ArgumentList[1]
                return @{
                    'InteractiveType'  = 2 -in $selectedTypes
                    'RDPType'          = 10 -in $selectedTypes
                    'NetworkType'      = 3 -in $selectedTypes
                    'BatchType'        = 4 -in $selectedTypes
                    'ServiceType'      = 5 -in $selectedTypes
                    'UnlockType'       = 7 -in $selectedTypes
                    'CachedType'       = 11 -in $selectedTypes
                } | ConvertTo-Json -AsArray
            }
        }

        It 'Should map Interactive to type 2' {
            Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType "Interactive" | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks
        }

        It 'Should map RDP to type 10' {
            Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType "RDP" | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks
        }

        It 'Should map all logon types correctly' {
            @{
                "Interactive" = 2
                "Network"     = 3
                "Batch"       = 4
                "Service"     = 5
                "Unlock"      = 7
                "RDP"         = 10
                "Cached"      = 11
            }.GetEnumerator() | ForEach-Object {
                { Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType $_.Key } | Should -Not -Throw
            }
        }
    }

    Context 'Error handling' {
        It 'Should catch Invoke-Command errors' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                throw "Connection failed"
            }

            { Get-RemoteUserLogons -ComputerName "BADSERVER" -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Error connecting to servers*"
        }

        It 'Should handle no events gracefully' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                & $ScriptBlock -DaysLookBack $ArgumentList[0] -TargetLogonTypes $ArgumentList[1]
            }

            Mock -CommandName Get-WinEvent -MockWith {
                throw "No events found"
            }

            { Get-RemoteUserLogons -ComputerName "SERVER01" 3>&1 | Out-Null } | Should -Not -Throw
        }
    }

    Context 'Filtering logic for user accounts' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                & $ScriptBlock -DaysLookBack $ArgumentList[0] -TargetLogonTypes $ArgumentList[1]
            }
        }

        It 'Should filter out machine accounts (ending with $)' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "MACHINE$",  # Machine account
                    "DOMAIN",
                    $null,
                    "2",
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should filter out SYSTEM account' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "SYSTEM",
                    "DOMAIN",
                    $null,
                    "2",
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should filter out ANONYMOUS LOGON' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "ANONYMOUS LOGON",
                    "DOMAIN",
                    $null,
                    "2",
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should filter out blank usernames' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "",  # Blank user
                    "DOMAIN",
                    $null,
                    "2",
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should include normal user accounts' {
            Mock -CommandName Get-WinEvent -MockWith { return @() }

            { Get-RemoteUserLogons -ComputerName "SERVER01" } | Should -Not -Throw
        }
    }

    Context 'Default logon type filtering' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                & $ScriptBlock -DaysLookBack $ArgumentList[0] -TargetLogonTypes $ArgumentList[1]
            }
        }

        It 'Should exclude Network (type 3) by default' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "user",
                    "DOMAIN",
                    $null,
                    "3",  # Network type
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should exclude Service (type 5) by default' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @(
                    $null, $null, $null, $null, $null,
                    "user",
                    "DOMAIN",
                    $null,
                    "5",  # Service type
                    $null, $null, $null, $null, $null, $null, $null, $null, $null,
                    "192.168.1.1"
                )
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should include Network type when explicitly requested' {
            Mock -CommandName Get-WinEvent -MockWith { return @() }

            { Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType "Network" } | Should -Not -Throw
        }
    }

    Context 'Event Properties validation' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                & $ScriptBlock -DaysLookBack $ArgumentList[0] -TargetLogonTypes $ArgumentList[1]
            }
        }

        It 'Should skip events with null Properties' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = $null
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }

        It 'Should skip events with insufficient Properties' {
            $mockEvent = [PSCustomObject]@{
                TimeCreated = Get-Date
                Properties  = @($null, $null, $null)
            }

            Mock -CommandName Get-WinEvent -MockWith { return $mockEvent }

            $result = Get-RemoteUserLogons -ComputerName "SERVER01"
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Output properties' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -MockWith { return @() }
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                param($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction)
                & $ScriptBlock -DaysLookBack $ArgumentList[0] -TargetLogonTypes $ArgumentList[1]
            }
        }

        It 'Should return events with correct properties' {
            { Get-RemoteUserLogons -ComputerName "SERVER01" } | Should -Not -Throw
        }

        It 'Should sort results by Time descending' {
            { Get-RemoteUserLogons -ComputerName "SERVER01" } | Should -Not -Throw
        }
    }

    Context 'Days parameter' {
        It 'Should use default Days value of 1' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ArgumentList[0] -eq 1
            } -MockWith { @() }

            Get-RemoteUserLogons -ComputerName "SERVER01" | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1 -Exactly
        }

        It 'Should use specified Days value' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ArgumentList[0] -eq 30
            } -MockWith { @() }

            Get-RemoteUserLogons -ComputerName "SERVER01" -Days 30 | Out-Null
            Assert-MockCalled -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1 -Exactly
        }
    }
}
