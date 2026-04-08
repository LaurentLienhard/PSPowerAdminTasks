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

Describe 'DNS Class' -Tag 'Unit' {

    Context 'Constructor - Empty (No Connection)' {

        It 'Should create an instance without throwing' {
            { & (Get-Module $script:moduleName) { [DNS]::new() } } | Should -Not -Throw
        }

        It 'Should leave ComputerName empty with default constructor' {
            $dns = & (Get-Module $script:moduleName) { [DNS]::new() }
            $dns.ComputerName | Should -BeNullOrEmpty
        }

        It 'Should leave Status empty with default constructor' {
            $dns = & (Get-Module $script:moduleName) { [DNS]::new() }
            $dns.Status | Should -BeNullOrEmpty
        }
    }

    Context 'Constructor - With ComputerName (Connection Fails Gracefully)' {

        BeforeAll {
            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                throw 'Connection refused'
            }
        }

        It 'Should set ComputerName when constructed with a name' {
            $dns = & (Get-Module $script:moduleName) { [DNS]::new('DNS-SERVER-01') }
            $dns.ComputerName | Should -Be 'DNS-SERVER-01'
        }

        It 'Should set Status to Connection Failed when CIM session cannot be established' {
            $dns = & (Get-Module $script:moduleName) { [DNS]::new('UNREACHABLE-DNS') }
            $dns.Status | Should -Be 'Connection Failed'
        }

        It 'Should set CheckTime when constructed with a name' {
            $dns = & (Get-Module $script:moduleName) { [DNS]::new('DNS-SERVER-01') }
            $dns.CheckTime | Should -Not -BeNullOrEmpty
            $dns.CheckTime | Should -BeOfType [datetime]
        }
    }

    Context 'GetAllZones - Not Connected' {

        It 'Should return an empty array when not connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.GetAllZones()
            }
            @($result).Count | Should -Be 0
        }
    }

    Context 'GetZone - Not Connected' {

        It 'Should return an empty array when not connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.GetZone('domain.local')
            }
            @($result).Count | Should -Be 0
        }
    }

    Context 'GetZoneRecords - Not Connected' {

        It 'Should return an empty array when not connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.GetZoneRecords('domain.local')
            }
            @($result).Count | Should -Be 0
        }
    }

    Context 'FindDuplicateEntries - Not Connected' {

        It 'Should return an empty array when not connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.FindDuplicateEntries(@())
            }
            @($result).Count | Should -Be 0
        }
    }

    Context 'Cleanup Method' {

        BeforeAll {
            Mock -CommandName Remove-CimSession -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should not throw when cleanup is called on a disconnected instance' {
            { & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.Cleanup()
            } } | Should -Not -Throw
        }

        It 'Should set Status to Disconnected after Cleanup with active session' {
            $dns = & (Get-Module $script:moduleName) {
                $d = [DNS]::new()
                $d.CimSession = [PSCustomObject]@{ Id = 99 }
                $d.Status = 'Connected'
                $d.Cleanup()
                $d
            }
            $dns.Status | Should -Be 'Disconnected'
        }

        It 'Should set CimSession to null after Cleanup' {
            $dns = & (Get-Module $script:moduleName) {
                $d = [DNS]::new()
                $d.CimSession = [PSCustomObject]@{ Id = 99 }
                $d.Status = 'Connected'
                $d.Cleanup()
                $d
            }
            $dns.CimSession | Should -BeNullOrEmpty
        }
    }

    Context 'GetAllZones - Connected' {

        BeforeAll {
            Mock -CommandName Get-DnsServerZone -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{ ZoneName = 'domain.local'; ZoneType = 'Primary' },
                    [PSCustomObject]@{ ZoneName = 'other.local'; ZoneType = 'Secondary' }
                )
            }
        }

        It 'Should return zones when connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.Status = 'Connected'
                $dns.CimSession = [PSCustomObject]@{ Id = 1 }
                $dns.GetAllZones()
            }
            @($result).Count | Should -Be 2
        }
    }

    Context 'FindDuplicateEntries - Connected With Duplicates' {

        BeforeAll {
            Mock -CommandName Get-DnsServerResourceRecord -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        HostName   = 'webserver'
                        RecordType = 'A'
                        Timestamp  = $null
                        RecordData = [PSCustomObject]@{ IPv4Address = [System.Net.IPAddress]::Parse('10.0.0.1') }
                    },
                    [PSCustomObject]@{
                        HostName   = 'webserver'
                        RecordType = 'A'
                        Timestamp  = $null
                        RecordData = [PSCustomObject]@{ IPv4Address = [System.Net.IPAddress]::Parse('10.0.0.2') }
                    }
                )
            }
        }

        It 'Should return duplicate records when they exist' {
            $result = & (Get-Module $script:moduleName) {
                $fakeZone = [PSCustomObject]@{ ZoneName = 'domain.local' }
                $dns = [DNS]::new()
                $dns.ComputerName = 'DNS01'
                $dns.Status = 'Connected'
                $dns.CimSession = [PSCustomObject]@{ Id = 1 }
                $dns.FindDuplicateEntries(@($fakeZone))
            }
            @($result).Count | Should -BeGreaterThan 0
        }
    }

    Context 'FindDuplicateEntries - No Duplicates' {

        BeforeAll {
            Mock -CommandName Get-DnsServerResourceRecord -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        HostName   = 'server1'
                        RecordType = 'A'
                        Timestamp  = $null
                        RecordData = [PSCustomObject]@{ IPv4Address = [System.Net.IPAddress]::Parse('10.0.0.1') }
                    }
                )
            }
        }

        It 'Should return an empty array when no duplicates exist' {
            $result = & (Get-Module $script:moduleName) {
                $fakeZone = [PSCustomObject]@{ ZoneName = 'domain.local' }
                $dns = [DNS]::new()
                $dns.ComputerName = 'DNS01'
                $dns.Status = 'Connected'
                $dns.CimSession = [PSCustomObject]@{ Id = 1 }
                $dns.FindDuplicateEntries(@($fakeZone))
            }
            @($result).Count | Should -Be 0
        }
    }
}
