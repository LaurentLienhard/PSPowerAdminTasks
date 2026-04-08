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

        It 'Should set ComputerName when constructed with a name' {
            $dns = & (Get-Module $script:moduleName) {
                Mock -CommandName New-CimSession { throw 'Connection refused' }
                [DNS]::new('DNS-SERVER-01')
            }
            $dns.ComputerName | Should -Be 'DNS-SERVER-01'
        }

        It 'Should set Status to Connection Failed when CIM session cannot be established' {
            $dns = & (Get-Module $script:moduleName) {
                Mock -CommandName New-CimSession { throw 'Connection refused' }
                [DNS]::new('UNREACHABLE-DNS')
            }
            $dns.Status | Should -Be 'Connection Failed'
        }

        It 'Should set CheckTime when constructed with a name' {
            $dns = & (Get-Module $script:moduleName) {
                Mock -CommandName New-CimSession { throw 'Connection refused' }
                [DNS]::new('DNS-SERVER-01')
            }
            $dns.CheckTime | Should -Not -BeNullOrEmpty
            $dns.CheckTime | Should -BeOfType [datetime]
        }
    }

    Context 'GetAllZones - Not Connected' {

        It 'Should return an empty array when not connected' {
            $result = & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                # Status is empty (not Connected), so it should return empty
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

        It 'Should not throw when cleanup is called on a disconnected instance' {
            { & (Get-Module $script:moduleName) {
                $dns = [DNS]::new()
                $dns.Cleanup()
            } } | Should -Not -Throw
        }

        It 'Should set Status to Disconnected after Cleanup with active session' {
            $dns = & (Get-Module $script:moduleName) {
                $fakeCimSession = [PSCustomObject]@{ Id = 99 }
                Mock -CommandName Remove-CimSession { }

                $dns = [DNS]::new()
                # Manually inject a fake CIM session to simulate connected state
                $dns.CimSession = $fakeCimSession
                $dns.Status = 'Connected'
                $dns.Cleanup()
                $dns
            }
            $dns.Status | Should -Be 'Disconnected'
        }

        It 'Should set CimSession to null after Cleanup' {
            $dns = & (Get-Module $script:moduleName) {
                $fakeCimSession = [PSCustomObject]@{ Id = 99 }
                Mock -CommandName Remove-CimSession { }

                $dns = [DNS]::new()
                $dns.CimSession = $fakeCimSession
                $dns.Status = 'Connected'
                $dns.Cleanup()
                $dns
            }
            $dns.CimSession | Should -BeNullOrEmpty
        }
    }

    Context 'GetAllZones - Connected' {

        It 'Should return zones when connected' {
            $result = & (Get-Module $script:moduleName) {
                Mock -CommandName Get-DnsServerZone {
                    @(
                        [PSCustomObject]@{ ZoneName = 'domain.local'; ZoneType = 'Primary' },
                        [PSCustomObject]@{ ZoneName = 'other.local'; ZoneType = 'Secondary' }
                    )
                }

                $dns = [DNS]::new()
                $dns.Status = 'Connected'
                $dns.CimSession = [PSCustomObject]@{ Id = 1 }
                $dns.GetAllZones()
            }
            @($result).Count | Should -Be 2
        }
    }

    Context 'FindDuplicateEntries - Connected With Duplicates' {

        It 'Should return duplicate records when they exist' {
            $result = & (Get-Module $script:moduleName) {
                $fakeZone = [PSCustomObject]@{ ZoneName = 'domain.local' }

                Mock -CommandName Get-DnsServerResourceRecord {
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

                $dns = [DNS]::new()
                $dns.ComputerName = 'DNS01'
                $dns.Status = 'Connected'
                $dns.CimSession = [PSCustomObject]@{ Id = 1 }
                $dns.FindDuplicateEntries(@($fakeZone))
            }
            @($result).Count | Should -BeGreaterThan 0
        }

        It 'Should return an empty array when no duplicates exist' {
            $result = & (Get-Module $script:moduleName) {
                $fakeZone = [PSCustomObject]@{ ZoneName = 'domain.local' }

                Mock -CommandName Get-DnsServerResourceRecord {
                    @(
                        [PSCustomObject]@{
                            HostName   = 'server1'
                            RecordType = 'A'
                            Timestamp  = $null
                            RecordData = [PSCustomObject]@{ IPv4Address = [System.Net.IPAddress]::Parse('10.0.0.1') }
                        }
                    )
                }

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
