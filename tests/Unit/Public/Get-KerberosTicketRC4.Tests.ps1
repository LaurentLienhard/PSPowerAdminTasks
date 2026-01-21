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

Describe 'Get-KerberosTicketRC4' {
    Context 'Default parameters - local machine, last 24 hours' {
        BeforeEach {
            $mockEvent1 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEvent1 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\User1</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.100</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            $mockEvent2 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 11:00:00'
                Id          = 4769
            }
            $mockEvent2 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">18</Data>
    <Data Name="ClientName">DOMAIN\User2</Data>
    <Data Name="ServiceName">HTTP/Server1.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.101</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEvent1, $mockEvent2)
            }
        }

        It 'Should return only RC4 encrypted tickets' {
            $result = Get-KerberosTicketRC4

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result.EncryptionType | Should -Be 'RC4-HMAC'
            $result.ClientName | Should -Be 'DOMAIN\User1'
        }

        It 'Should call Get-WinEvent' {
            Get-KerberosTicketRC4 | Out-Null

            Assert-MockCalled -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -Times 1 -Scope It
        }
    }

    Context 'Multiple computers parameter' {
        BeforeEach {
            $mockEventRC4 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEventRC4 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\ServiceAccount</Data>
    <Data Name="ServiceName">MSSQLSvc/SQL.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.50</Data>
    <Data Name="Status">0x18</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventRC4)
            }
        }

        It 'Should query multiple domain controllers' {
            Get-KerberosTicketRC4 -ComputerName 'DC1', 'DC2' | Out-Null

            Assert-MockCalled -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -Times 2 -Scope It
        }

        It 'Should return results from all computers' {
            $result = Get-KerberosTicketRC4 -ComputerName 'DC1', 'DC2'

            @($result).Count | Should -Be 2
            $result[0].ComputerName | Should -Be 'DC1'
            $result[1].ComputerName | Should -Be 'DC2'
        }
    }

    Context 'Hours parameter' {
        BeforeEach {
            $mockEvent = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-20 10:00:00'
                Id          = 4769
            }
            $mockEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">23</Data>
    <Data Name="ClientName">DOMAIN\OldUser</Data>
    <Data Name="ServiceName">LDAP/DC.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.99</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEvent)
            }
        }

        It 'Should query last 72 hours' {
            $result = Get-KerberosTicketRC4 -Hours 72

            $result | Should -Not -BeNullOrEmpty
            Assert-MockCalled -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -Times 1 -Scope It
        }
    }

    Context 'ShowAll parameter' {
        BeforeEach {
            $mockEventRC4 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEventRC4 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\User1</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.100</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            $mockEventAES = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:45:00'
                Id          = 4769
            }
            $mockEventAES | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">18</Data>
    <Data Name="ClientName">DOMAIN\User2</Data>
    <Data Name="ServiceName">HTTP/Server1.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.101</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventRC4, $mockEventAES)
            }
        }

        It 'Should return all tickets when ShowAll is set' {
            $result = Get-KerberosTicketRC4 -ShowAll

            @($result).Count | Should -Be 2
        }

        It 'Should include non-RC4 types' {
            $result = Get-KerberosTicketRC4 -ShowAll

            $aesTickets = @($result) | Where-Object { $_.TicketEncryptionType -eq 18 }
            $aesTickets | Should -Not -BeNullOrEmpty
        }
    }

    Context 'IncludeSuccess parameter' {
        BeforeEach {
            $mockEventSuccess = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEventSuccess | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\User1</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.100</Data>
    <Data Name="Status">0x0</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventSuccess)
            }
        }

        It 'Should exclude successful tickets by default' {
            $result = Get-KerberosTicketRC4

            $result | Should -BeNullOrEmpty
        }

        It 'Should include successful tickets with IncludeSuccess' {
            $result = Get-KerberosTicketRC4 -IncludeSuccess

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be '0x0'
        }
    }

    Context 'Encryption type mapping' {
        BeforeEach {
            $mockEventDES = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:00:00'
                Id          = 4769
            }
            $mockEventDES | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">1</Data>
    <Data Name="ClientName">DOMAIN\LegacyUser</Data>
    <Data Name="ServiceName">host/legacyapp.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.50</Data>
    <Data Name="Status">0x1F</Data>
  </EventData>
</Event>
'@
            }

            $mockEventRC4Alt = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:15:00'
                Id          = 4769
            }
            $mockEventRC4Alt | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">23</Data>
    <Data Name="ClientName">DOMAIN\User2</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.101</Data>
    <Data Name="Status">0x1F</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventDES, $mockEventRC4Alt)
            }
        }

        It 'Should map type 1 to DES-CBC-CRC' {
            $result = Get-KerberosTicketRC4 -ShowAll

            $desTicket = @($result) | Where-Object { $_.TicketEncryptionType -eq 1 }
            $desTicket.EncryptionType | Should -Be 'DES-CBC-CRC'
        }

        It 'Should map type 23 to RC4-HMAC' {
            $result = Get-KerberosTicketRC4 -ShowAll

            $rc4Ticket = @($result) | Where-Object { $_.TicketEncryptionType -eq 23 }
            $rc4Ticket.EncryptionType | Should -Be 'RC4-HMAC'
        }

        It 'Should handle unknown encryption types' {
            $mockEventUnknown = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEventUnknown | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">999</Data>
    <Data Name="ClientName">DOMAIN\TestUser</Data>
    <Data Name="ServiceName">test/service.domain.com</Data>
    <Data Name="ClientAddress">192.168.1.102</Data>
    <Data Name="Status">0x1F</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventUnknown)
            }

            $result = Get-KerberosTicketRC4 -ShowAll

            $result.EncryptionType | Should -Match 'Unknown'
        }
    }

    Context 'Event data extraction' {
        BeforeEach {
            $mockEvent = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 14:25:30'
                Id          = 4769
            }
            $mockEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\TestUser</Data>
    <Data Name="ServiceName">HTTP/WebServer.domain.com</Data>
    <Data Name="ClientAddress">10.0.0.50</Data>
    <Data Name="Status">0x18</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEvent)
            }
        }

        It 'Should extract ClientName correctly' {
            $result = Get-KerberosTicketRC4

            $result.ClientName | Should -Be 'DOMAIN\TestUser'
        }

        It 'Should extract ServiceName correctly' {
            $result = Get-KerberosTicketRC4

            $result.ServiceName | Should -Be 'HTTP/WebServer.domain.com'
        }

        It 'Should extract ClientAddress correctly' {
            $result = Get-KerberosTicketRC4

            $result.ClientAddress | Should -Be '10.0.0.50'
        }

        It 'Should extract Status correctly' {
            $result = Get-KerberosTicketRC4

            $result.Status | Should -Be '0x18'
        }

        It 'Should populate ComputerName' {
            $result = Get-KerberosTicketRC4 -ComputerName 'TestDC'

            $result.ComputerName | Should -Be 'TestDC'
        }

        It 'Should populate TimeCreated' {
            $result = Get-KerberosTicketRC4

            $result.TimeCreated | Should -Be $mockEvent.TimeCreated
        }

        It 'Should populate EventID' {
            $result = Get-KerberosTicketRC4

            $result.EventID | Should -Be 4769
        }
    }

    Context 'Error handling' {
        It 'Should handle Get-WinEvent errors' {
            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                throw 'Access denied'
            }

            { Get-KerberosTicketRC4 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should handle empty logs' {
            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            $result = Get-KerberosTicketRC4

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Output format' {
        BeforeEach {
            $mockEvent = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\User</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.1</Data>
    <Data Name="Status">0x1</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEvent)
            }
        }

        It 'Should return PSCustomObject' {
            $result = Get-KerberosTicketRC4

            $result | Should -BeOfType [System.Management.Automation.PSCustomObject]
        }

        It 'Should have expected properties' {
            $result = Get-KerberosTicketRC4

            $result | Should -HaveProperty 'TimeCreated'
            $result | Should -HaveProperty 'ClientName'
            $result | Should -HaveProperty 'ServiceName'
            $result | Should -HaveProperty 'EncryptionType'
            $result | Should -HaveProperty 'TicketEncryptionType'
            $result | Should -HaveProperty 'ClientAddress'
            $result | Should -HaveProperty 'Status'
            $result | Should -HaveProperty 'EventID'
            $result | Should -HaveProperty 'ComputerName'
        }

        It 'Should not have null key properties' {
            $result = Get-KerberosTicketRC4

            $result.ClientName | Should -Not -BeNullOrEmpty
            $result.ServiceName | Should -Not -BeNullOrEmpty
            $result.EncryptionType | Should -Not -BeNullOrEmpty
        }
    }

    Context 'RC4 detection logic' {
        BeforeEach {
            $mockEventRC4Type3 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:00:00'
                Id          = 4769
            }
            $mockEventRC4Type3 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">3</Data>
    <Data Name="ClientName">DOMAIN\User1</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.1</Data>
    <Data Name="Status">0x1</Data>
  </EventData>
</Event>
'@
            }

            $mockEventRC4Type23 = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:15:00'
                Id          = 4769
            }
            $mockEventRC4Type23 | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">23</Data>
    <Data Name="ClientName">DOMAIN\User2</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.2</Data>
    <Data Name="Status">0x1</Data>
  </EventData>
</Event>
'@
            }

            $mockEventAES = New-Object PSObject -Property @{
                TimeCreated = [datetime]'2025-01-21 10:30:00'
                Id          = 4769
            }
            $mockEventAES | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                return @'
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <EventData>
    <Data Name="TicketEncryptionType">18</Data>
    <Data Name="ClientName">DOMAIN\User3</Data>
    <Data Name="ServiceName">krbtgt/DOMAIN.COM</Data>
    <Data Name="ClientAddress">192.168.1.3</Data>
    <Data Name="Status">0x1</Data>
  </EventData>
</Event>
'@
            }

            Mock -CommandName Get-WinEvent -ModuleName PSPowerAdminTasks -MockWith {
                return @($mockEventRC4Type3, $mockEventRC4Type23, $mockEventAES)
            }
        }

        It 'Should detect RC4 type 3' {
            $result = Get-KerberosTicketRC4

            $rc4Type3 = @($result) | Where-Object { $_.TicketEncryptionType -eq 3 }
            $rc4Type3 | Should -Not -BeNullOrEmpty
        }

        It 'Should detect RC4 type 23' {
            $result = Get-KerberosTicketRC4

            $rc4Type23 = @($result) | Where-Object { $_.TicketEncryptionType -eq 23 }
            $rc4Type23 | Should -Not -BeNullOrEmpty
        }

        It 'Should exclude AES256' {
            $result = Get-KerberosTicketRC4

            $aesTickets = @($result) | Where-Object { $_.TicketEncryptionType -eq 18 }
            $aesTickets | Should -BeNullOrEmpty
        }

        It 'Should return both RC4 types' {
            $result = Get-KerberosTicketRC4

            @($result).Count | Should -Be 2
        }
    }
}
