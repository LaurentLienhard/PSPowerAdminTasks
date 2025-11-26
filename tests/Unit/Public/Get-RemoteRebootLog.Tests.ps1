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
                [string]$ComputerName,
                [hashtable]$FilterHashtable,
                [int]$MaxEvents,
                [PSCredential]$Credential
            )
        }
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
    Remove-Item -Path function:global:Get-WinEvent -ErrorAction SilentlyContinue
}

Describe 'Get-RemoteRebootLog' -Tag 'Unit' {
    BeforeAll {
        # Mock event data for Event ID 1074 (User initiated restart)
        $script:mockEvent1074 = [PSCustomObject]@{
            TimeCreated = (Get-Date '2024-01-15 14:30:00')
            Id          = 1074
            MachineName = 'TestServer01'
            Properties  = @()
        }
        # Add ToXml method
        $script:mockEvent1074 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
            @"
<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
    <EventData>
        <Data>C:\Windows\System32\shutdown.exe</Data>
        <Data></Data>
        <Data>0x80020002</Data>
        <Data></Data>
        <Data>restart</Data>
        <Data>Maintenance planifiée</Data>
        <Data>DOMAIN\AdminUser</Data>
    </EventData>
</Event>
"@
        } -Force

        # Mock event data for Event ID 6006 (Clean shutdown)
        $script:mockEvent6006 = [PSCustomObject]@{
            TimeCreated = (Get-Date '2024-01-15 14:29:00')
            Id          = 6006
            MachineName = 'TestServer01'
            Properties  = @()
        }
        $script:mockEvent6006 | Add-Member -MemberType ScriptMethod -Name ToXml -Value { '<Event></Event>' } -Force

        # Mock event data for Event ID 6008 (Unexpected shutdown)
        $script:mockEvent6008 = [PSCustomObject]@{
            TimeCreated = (Get-Date '2024-01-14 10:15:00')
            Id          = 6008
            MachineName = 'TestServer01'
            Properties  = @(
                [PSCustomObject]@{ Value = '10:14:32' }
                [PSCustomObject]@{ Value = '2024-01-14' }
            )
        }
        $script:mockEvent6008 | Add-Member -MemberType ScriptMethod -Name ToXml -Value { '<Event></Event>' } -Force

        # Mock event data for Event ID 1076 (Shutdown reason)
        $script:mockEvent1076 = [PSCustomObject]@{
            TimeCreated = (Get-Date '2024-01-15 14:30:05')
            Id          = 1076
            MachineName = 'TestServer01'
            Properties  = @()
        }
        $script:mockEvent1076 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
            @"
<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
    <EventData>
        <Data></Data>
        <Data></Data>
        <Data></Data>
        <Data>DOMAIN\AdminUser</Data>
        <Data>0x80020002</Data>
        <Data>Mise à jour système</Data>
    </EventData>
</Event>
"@
        } -Force

        # Mock event with "power off" shutdown type
        $script:mockEvent1074Shutdown = [PSCustomObject]@{
            TimeCreated = (Get-Date '2024-01-16 18:00:00')
            Id          = 1074
            MachineName = 'TestServer01'
            Properties  = @()
        }
        $script:mockEvent1074Shutdown | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
            @"
<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>
    <EventData>
        <Data>C:\Windows\System32\shutdown.exe</Data>
        <Data></Data>
        <Data>0x80020012</Data>
        <Data></Data>
        <Data>power off</Data>
        <Data>Arrêt pour maintenance</Data>
        <Data>NT AUTHORITY\SYSTEM</Data>
    </EventData>
</Event>
"@
        } -Force
    }

    Context 'Parameter Validation' {
        It 'Should have ComputerName as a mandatory parameter' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['ComputerName'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept ComputerName from pipeline' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should accept ComputerName from pipeline by property name' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['ComputerName'].Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have Credential as an optional parameter' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['Credential'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept PSCredential type for Credential parameter' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'Should have MaxEvents parameter with default value of 50' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['MaxEvents'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should validate MaxEvents range (1-1000)' {
            $command = Get-Command Get-RemoteRebootLog
            $validateRange = $command.Parameters['MaxEvents'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 1000
        }

        It 'Should have StartTime parameter with DateTime type' {
            $command = Get-Command Get-RemoteRebootLog
            $command.Parameters['StartTime'].ParameterType.Name | Should -Be 'DateTime'
        }
    }

    Context 'Functionality with Event ID 1074 (User initiated restart)' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should call Get-WinEvent with correct parameters' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'TestServer01' -and
                $FilterHashtable.LogName -eq 'System' -and
                $FilterHashtable.ID -contains 1074
            }
        }

        It 'Should return reboot log data' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
        }

        It 'Should parse Event ID 1074 correctly' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.EventID | Should -Be 1074
            $result.Type | Should -Be 'Restart'
            $result.User | Should -Be 'DOMAIN\AdminUser'
            $result.Process | Should -Be 'C:\Windows\System32\shutdown.exe'
            $result.Reason | Should -Be '0x80020002'
            $result.Comment | Should -Be 'Maintenance planifiée'
        }

        It 'Should include all expected properties' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.PSObject.Properties.Name | Should -Contain 'TimeCreated'
            $result.PSObject.Properties.Name | Should -Contain 'EventID'
            $result.PSObject.Properties.Name | Should -Contain 'Computer'
            $result.PSObject.Properties.Name | Should -Contain 'User'
            $result.PSObject.Properties.Name | Should -Contain 'Reason'
            $result.PSObject.Properties.Name | Should -Contain 'Process'
            $result.PSObject.Properties.Name | Should -Contain 'Comment'
            $result.PSObject.Properties.Name | Should -Contain 'Type'
        }

        It 'Should parse shutdown type as "Shutdown" when power off' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074Shutdown)
            }

            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.Type | Should -Be 'Shutdown'
        }
    }

    Context 'Functionality with Event ID 6006 (Clean shutdown)' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent6006)
            }
        }

        It 'Should parse Event ID 6006 correctly' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.EventID | Should -Be 6006
            $result.Type | Should -Be 'Shutdown propre'
            $result.Reason | Should -Be 'Service Event Log arrêté'
        }
    }

    Context 'Functionality with Event ID 6008 (Unexpected shutdown)' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent6008)
            }
        }

        It 'Should parse Event ID 6008 correctly' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.EventID | Should -Be 6008
            $result.Type | Should -Be 'Shutdown imprévu'
            $result.Reason | Should -Be 'Arrêt inattendu du système (crash/panne)'
            $result.Comment | Should -Match 'Dernière heure de boot connue'
        }
    }

    Context 'Functionality with Event ID 1076 (Shutdown reason)' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1076)
            }
        }

        It 'Should parse Event ID 1076 correctly' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result.EventID | Should -Be 1076
            $result.Type | Should -Be 'Information raison shutdown'
            $result.User | Should -Be 'DOMAIN\AdminUser'
            $result.Reason | Should -Be '0x80020002'
            $result.Comment | Should -Be 'Mise à jour système'
        }
    }

    Context 'Functionality with multiple events' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @(
                    $script:mockEvent1074,
                    $script:mockEvent6006,
                    $script:mockEvent6008,
                    $script:mockEvent1076
                )
            }
        }

        It 'Should return all events' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 4
        }

        It 'Should parse each event type correctly' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            ($result | Where-Object { $_.EventID -eq 1074 }).Type | Should -Be 'Restart'
            ($result | Where-Object { $_.EventID -eq 6006 }).Type | Should -Be 'Shutdown propre'
            ($result | Where-Object { $_.EventID -eq 6008 }).Type | Should -Be 'Shutdown imprévu'
            ($result | Where-Object { $_.EventID -eq 1076 }).Type | Should -Be 'Information raison shutdown'
        }
    }

    Context 'Functionality with credentials' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }

            $script:testCredential = New-Object System.Management.Automation.PSCredential(
                'TestUser',
                (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
            )
        }

        It 'Should pass Credential to Get-WinEvent when provided' {
            Get-RemoteRebootLog -ComputerName 'TestServer01' -Credential $script:testCredential

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $Credential -ne $null -and $Credential.UserName -eq 'TestUser'
            }
        }

        It 'Should not pass Credential to Get-WinEvent when not provided' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $PSBoundParameters.ContainsKey('Credential') -eq $false
            }
        }
    }

    Context 'Functionality with MaxEvents parameter' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should pass MaxEvents parameter to Get-WinEvent' {
            Get-RemoteRebootLog -ComputerName 'TestServer01' -MaxEvents 100

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $MaxEvents -eq 100
            }
        }

        It 'Should use default MaxEvents of 50 when not specified' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $MaxEvents -eq 50
            }
        }
    }

    Context 'Functionality with StartTime parameter' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }

            $script:testStartTime = (Get-Date).AddDays(-7)
        }

        It 'Should pass StartTime to Get-WinEvent filter' {
            Get-RemoteRebootLog -ComputerName 'TestServer01' -StartTime $script:testStartTime

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $FilterHashtable.StartTime -eq $script:testStartTime
            }
        }

        It 'Should use default StartTime of 30 days when not specified' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $FilterHashtable.StartTime -lt (Get-Date) -and
                $FilterHashtable.StartTime -gt (Get-Date).AddDays(-31)
            }
        }
    }

    Context 'Pipeline input' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should accept computer names from pipeline' {
            'Server01', 'Server02' | Get-RemoteRebootLog

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -Times 2 -Exactly
        }

        It 'Should accept objects with ComputerName property from pipeline' {
            $computers = @(
                [PSCustomObject]@{ ComputerName = 'Server01'; Location = 'DC1' }
                [PSCustomObject]@{ ComputerName = 'Server02'; Location = 'DC2' }
            )

            $computers | Get-RemoteRebootLog

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -Times 2 -Exactly
        }

        It 'Should process each computer in the pipeline' {
            'Server01', 'Server02' | Get-RemoteRebootLog

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $ComputerName -eq 'Server01'
            }
            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $ComputerName -eq 'Server02'
            }
        }
    }

    Context 'Error handling - No events found' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                $exception = New-Object System.Exception('No events were found that match the specified selection criteria')
                throw $exception
            }
        }

        It 'Should handle "No events found" error gracefully' {
            { Get-RemoteRebootLog -ComputerName 'TestServer01' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should write verbose message when no events found' {
            $verboseOutput = Get-RemoteRebootLog -ComputerName 'TestServer01' -Verbose -ErrorAction SilentlyContinue 4>&1

            $verboseOutput | Where-Object { $_ -match 'Aucun événement de reboot trouvé' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling - RPC server unavailable' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                throw 'The RPC server is unavailable'
            }
            Mock -CommandName Write-Error -ModuleName $script:moduleName
        }

        It 'Should write error when RPC server is unavailable' {
            Get-RemoteRebootLog -ComputerName 'UnreachableServer' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Write-Error -ModuleName $script:moduleName -ParameterFilter {
                $Message -match 'Impossible de se connecter'
            }
        }
    }

    Context 'Error handling - Access denied' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                throw 'Access is denied'
            }
            Mock -CommandName Write-Error -ModuleName $script:moduleName
        }

        It 'Should write error when access is denied' {
            Get-RemoteRebootLog -ComputerName 'TestServer01' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Write-Error -ModuleName $script:moduleName -ParameterFilter {
                $Message -match 'Accès refusé'
            }
        }
    }

    Context 'Error handling - Generic error' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                throw 'Some unexpected error occurred'
            }
            Mock -CommandName Write-Error -ModuleName $script:moduleName
        }

        It 'Should write error with exception message for unknown errors' {
            Get-RemoteRebootLog -ComputerName 'TestServer01' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Write-Error -ModuleName $script:moduleName -ParameterFilter {
                $Message -match 'Erreur lors de la récupération'
            }
        }
    }

    Context 'Error handling - Continue on error' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                param($ComputerName)
                if ($ComputerName -eq 'FailServer') {
                    throw 'Connection failed'
                }
                return @($script:mockEvent1074)
            }
            Mock -CommandName Write-Error -ModuleName $script:moduleName
        }

        It 'Should continue processing other computers when one fails' {
            Get-RemoteRebootLog -ComputerName 'FailServer', 'GoodServer' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -Times 2 -Exactly
            Should -Invoke -CommandName Write-Error -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }

    Context 'Verbose output' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should write verbose messages when -Verbose is used' {
            $verboseOutput = Get-RemoteRebootLog -ComputerName 'TestServer01' -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match 'Début de la recherche des logs de reboot' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match 'Connexion à TestServer01' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match 'Trouvé' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match 'Fin de la recherche des logs de reboot' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Empty result handling' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return $null
            }
        }

        It 'Should handle null results gracefully' {
            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'

            $result | Should -BeNullOrEmpty
        }

        It 'Should write verbose message when no events are returned' {
            $verboseOutput = Get-RemoteRebootLog -ComputerName 'TestServer01' -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match 'Aucun événement de reboot trouvé' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Filter hashtable construction' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should include all required event IDs in filter' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $FilterHashtable.ID -contains 1074 -and
                $FilterHashtable.ID -contains 6006 -and
                $FilterHashtable.ID -contains 6008 -and
                $FilterHashtable.ID -contains 1076
            }
        }

        It 'Should set LogName to System in filter' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $FilterHashtable.LogName -eq 'System'
            }
        }

        It 'Should set ErrorAction to Stop' {
            Get-RemoteRebootLog -ComputerName 'TestServer01'

            Should -Invoke -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $ErrorAction -eq 'Stop'
            }
        }
    }

    Context 'BEGIN and END blocks' {
        BeforeEach {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($script:mockEvent1074)
            }
        }

        It 'Should execute BEGIN block before processing' {
            $verboseOutput = Get-RemoteRebootLog -ComputerName 'TestServer01' -Verbose 4>&1

            # The BEGIN block should write this verbose message first
            $messages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $messages[0].Message | Should -Match 'Début de la recherche'
        }

        It 'Should execute END block after processing' {
            $verboseOutput = Get-RemoteRebootLog -ComputerName 'TestServer01' -Verbose 4>&1

            # The END block should write this verbose message last
            $messages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $messages[-1].Message | Should -Match 'Fin de la recherche'
        }
    }

    Context 'Event data edge cases' {
        It 'Should handle event with missing EventData gracefully' {
            $mockEventNoData = [PSCustomObject]@{
                TimeCreated = (Get-Date)
                Id          = 1074
                MachineName = 'TestServer01'
                Properties  = @()
            }
            $mockEventNoData | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                '<Event><EventData></EventData></Event>'
            } -Force

            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($mockEventNoData)
            }

            { Get-RemoteRebootLog -ComputerName 'TestServer01' } | Should -Not -Throw
        }

        It 'Should handle Event ID 6008 without Properties' {
            $mockEvent6008NoProps = [PSCustomObject]@{
                TimeCreated = (Get-Date)
                Id          = 6008
                MachineName = 'TestServer01'
                Properties  = $null
            }
            $mockEvent6008NoProps | Add-Member -MemberType ScriptMethod -Name ToXml -Value { '<Event></Event>' } -Force

            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                return @($mockEvent6008NoProps)
            }

            $result = Get-RemoteRebootLog -ComputerName 'TestServer01'
            $result.Comment | Should -Be 'N/A'
        }
    }
}
