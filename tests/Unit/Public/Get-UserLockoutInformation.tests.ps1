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

Describe 'Get-UserLockoutInformation' -Tag 'Unit' {

    Context 'Parameter Acceptance' {

        It 'Should accept DC parameter' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            { Get-UserLockoutInformation -DC 'DC01' -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept Identity parameter' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            { Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept Credential parameter' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }
            $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

            { Get-UserLockoutInformation -DC 'DC01' -Credential $cred -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept pipeline input for Identity' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            { 'TestUser' | Get-UserLockoutInformation -DC 'DC01' -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Event Log Querying' {

        It 'Should query Security event log for EventID 4740' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter {
                $FilterHashtable.LogName -eq 'Security' -and $FilterHashtable.Id -eq 4740
            } -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            { Get-UserLockoutInformation -DC 'DC01' -ErrorAction Stop } | Should -Not -Throw
            Should -Invoke -CommandName Get-WinEvent -Times 1
        }

        It 'Should throw when no lockout events found' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith { $null }

            { Get-UserLockoutInformation -DC 'DC01' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*No event found*'
        }

        It 'Should throw when elevated rights required' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                throw [System.UnauthorizedAccessException]'You need an elevated user rights'
            }

            { Get-UserLockoutInformation -DC 'DC01' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*elevated user rights*'
        }
    }

    Context 'ParameterSet: All' {

        It 'Should process all locked out users when no Identity specified' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        Id           = 4740
                        TimeCreated  = (Get-Date).AddMinutes(-10)
                        MachineName  = 'DC01'
                        Message      = 'User account locked out'
                        Properties   = @(
                            [PSCustomObject]@{value = 'User1'},
                            [PSCustomObject]@{Value = 'COMPUTER01'},
                            [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                        )
                    },
                    [PSCustomObject]@{
                        Id           = 4740
                        TimeCreated  = (Get-Date).AddMinutes(-5)
                        MachineName  = 'DC01'
                        Message      = 'User account locked out'
                        Properties   = @(
                            [PSCustomObject]@{value = 'User2'},
                            [PSCustomObject]@{Value = 'COMPUTER02'},
                            [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1014'}
                        )
                    }
                )
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -ErrorAction SilentlyContinue

            $result | Should -HaveCount 2
        }

        It 'Should return basic lockout info without connecting to source computer' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -ErrorAction SilentlyContinue

            $result.User | Should -Be 'TestUser'
            $result.DomainController | Should -Be 'DC01'
            $result.EventId | Should -Be 4740
            $result.LockoutSource | Should -Be 'COMPUTER01'
        }
    }

    Context 'ParameterSet: ByUser' {

        It 'Should return lockout info for specific user' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction SilentlyContinue

            $result.User | Should -Be 'TestUser'
            $result | Should -HaveProperty 'User'
            $result | Should -HaveProperty 'DomainController'
            $result | Should -HaveProperty 'EventId'
            $result | Should -HaveProperty 'LockoutTimeStamp'
            $result | Should -HaveProperty 'LockoutSource'
        }

        It 'Should filter events by user SID' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                @(
                    [PSCustomObject]@{
                        Id           = 4740
                        TimeCreated  = Get-Date
                        MachineName  = 'DC01'
                        Message      = 'User account locked out'
                        Properties   = @(
                            [PSCustomObject]@{value = 'User1'},
                            [PSCustomObject]@{Value = 'COMPUTER01'},
                            [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                        )
                    },
                    [PSCustomObject]@{
                        Id           = 4740
                        TimeCreated  = Get-Date
                        MachineName  = 'DC01'
                        Message      = 'User account locked out'
                        Properties   = @(
                            [PSCustomObject]@{value = 'TestUser'},
                            [PSCustomObject]@{Value = 'COMPUTER02'},
                            [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1014'}
                        )
                    }
                )
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1014'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction SilentlyContinue

            $result.User | Should -Be 'TestUser'
        }
    }

    Context 'Lockout Reason Retrieval' {

        It 'Should attempt to connect to lockout source computer' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -ParameterFilter { $ComputerName -eq 'COMPUTER01' } -MockWith { $true }

            { Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction SilentlyContinue } | Should -Not -Throw
            Should -Invoke -CommandName Test-Connection -ParameterFilter { $ComputerName -eq 'COMPUTER01' } -Times 1
        }

        It 'Should handle source computer unreachable gracefully' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction SilentlyContinue

            # Should still return basic info even if source is unreachable
            $result | Should -Not -BeNullOrEmpty
            $result.User | Should -Be 'TestUser'
        }
    }

    Context 'Output Structure' {

        It 'Should return PSCustomObject with all expected properties' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -ErrorAction SilentlyContinue

            $result | Should -HaveProperty 'User'
            $result | Should -HaveProperty 'DomainController'
            $result | Should -HaveProperty 'EventId'
            $result | Should -HaveProperty 'LockoutTimeStamp'
            $result | Should -HaveProperty 'Message'
            $result | Should -HaveProperty 'LockoutSource'
            $result | Should -HaveProperty 'LockedUserName'
            $result | Should -HaveProperty 'LogonType'
            $result | Should -HaveProperty 'LogonProcessName'
            $result | Should -HaveProperty 'ProcessName'
            $result | Should -HaveProperty 'FailureReason'
            $result | Should -HaveProperty 'FailureStatus'
            $result | Should -HaveProperty 'FailureSubStatus'
        }

        It 'Should have correct EventId value' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01' -ErrorAction SilentlyContinue

            $result.EventId | Should -Be 4740
        }

        It 'Should have DomainController property with correct value' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01.domain.local'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            $result = Get-UserLockoutInformation -DC 'DC01.domain.local' -ErrorAction SilentlyContinue

            $result.DomainController | Should -Be 'DC01.domain.local'
        }
    }

    Context 'Error Handling' {

        It 'Should handle Get-ADUser not finding user' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith { throw 'User not found' }

            { Get-UserLockoutInformation -DC 'DC01' -Identity 'NonExistentUser' -ErrorAction Stop } | Should -Throw
        }

        It 'Should handle event reason query failures gracefully' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter { $FilterHashtable.Id -eq 4740 } -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name = 'TestUser'
                    SID  = [PSCustomObject]@{Value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                }
            }
            Mock -CommandName Test-Connection -MockWith { $true }
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -ParameterFilter { $FilterHashtable.Id -eq 4625 } -MockWith { throw 'Error retrieving events' }

            # Should still return basic lockout info even if reason query fails
            $result = Get-UserLockoutInformation -DC 'DC01' -Identity 'TestUser' -ErrorAction SilentlyContinue

            $result | Should -Not -BeNullOrEmpty
            $result.User | Should -Be 'TestUser'
        }
    }

    Context 'Verbose Output' {

        It 'Should support Verbose parameter' {
            Mock -CommandName Get-WinEvent -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Id           = 4740
                    TimeCreated  = Get-Date
                    MachineName  = 'DC01'
                    Message      = 'User account locked out'
                    Properties   = @(
                        [PSCustomObject]@{value = 'TestUser'},
                        [PSCustomObject]@{Value = 'COMPUTER01'},
                        [PSCustomObject]@{value = 'S-1-5-21-3623811015-3361044348-30300820-1013'}
                    )
                }
            }
            Mock -CommandName Test-Connection -ModuleName $script:moduleName -MockWith { $false }

            { Get-UserLockoutInformation -DC 'DC01' -Verbose -ErrorAction SilentlyContinue 4>&1 } | Should -Not -Throw
        }
    }

}
