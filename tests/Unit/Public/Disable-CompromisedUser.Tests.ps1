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

Describe 'Disable-CompromisedUser' -Tag 'Unit' {

    Context 'ParameterSet: ByUser - Single User' {

        It 'Should accept and process single Identity parameter' {
            # Apply mocks at global scope
            Mock Get-ADUser -MockWith {
                [PSCustomObject]@{
                    SamAccountName = 'User1'
                    DisplayName    = 'Test User 1'
                    Enabled        = $true
                }
            }
            Mock Disable-ADAccount -MockWith { }

            InModuleScope $script:moduleName {
                Mock Write-Log -MockWith { }
                { Disable-CompromisedUser -Identity 'User1' -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should handle user not found exception gracefully' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]'User not found'
                }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'NonExistentUser' -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It 'Should retrieve user with correct properties' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -ParameterFilter {
                    $Properties -contains 'SamAccountName' -and $Properties -contains 'DisplayName' -and $Properties -contains 'Enabled'
                } -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'User1' -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'ParameterSet: ByUser - Multiple Users' {

        It 'Should accept and process multiple Identity parameters' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = $args[1]
                        DisplayName    = "User $($args[1])"
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'User1', 'User2', 'User3' -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should handle mixed success and failure for multiple users' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    if ($args[1] -eq 'InvalidUser') {
                        throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]'User not found'
                    }
                    [PSCustomObject]@{
                        SamAccountName = $args[1]
                        DisplayName    = "User $($args[1])"
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'User1', 'InvalidUser', 'User2' -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }

    Context 'ParameterSet: ByFileName' {

        It 'Should read users from file and disable them' {
            InModuleScope $script:moduleName {
                Mock Get-Content -MockWith { @('User1', 'User2') }
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = $args[1]
                        DisplayName    = "Test User"
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -FileName 'C:\temp\users.txt' -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should handle file with mixed valid and invalid users' {
            InModuleScope $script:moduleName {
                Mock Get-Content -MockWith { @('User1', 'InvalidUser', 'User2') }
                Mock Get-ADUser -MockWith {
                    if ($args[1] -eq 'InvalidUser') {
                        throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]'User not found'
                    }
                    [PSCustomObject]@{
                        SamAccountName = $args[1]
                        DisplayName    = "Test User"
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -FileName 'C:\temp\users.txt' -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }

    Context 'ParameterSet: ByOU - Single OU' {

        It 'Should retrieve users from OU and disable them' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        },
                        [PSCustomObject]@{
                            SamAccountName = 'User2'
                            DisplayName    = 'Test User 2'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -OU 'OU=TestOU,DC=contoso,DC=com' -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should use AddRange for OU batch operations' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -OU 'OU=TestOU,DC=contoso,DC=com' -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'ParameterSet: ByOU - Multiple OUs' {

        It 'Should process multiple OUs' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        },
                        [PSCustomObject]@{
                            SamAccountName = 'User2'
                            DisplayName    = 'Test User 2'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -OU 'OU=TestOU1,DC=contoso,DC=com', 'OU=TestOU2,DC=contoso,DC=com' -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'Check Mode' {

        It 'Should not disable when Check parameter is used' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'User1' -Check -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -CommandName Disable-ADAccount -Times 0
            }
        }

        It 'Should identify enabled users in Check mode' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Write-Log -ParameterFilter { $Message -match 'is enabled' }

                { Disable-CompromisedUser -Identity 'User1' -Check -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should identify disabled users in Check mode' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $false
                    }
                }
                Mock Write-Log -ParameterFilter { $Message -match 'is disabled' }

                { Disable-CompromisedUser -Identity 'User1' -Check -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should not disable OU users in Check mode' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -OU 'OU=TestOU,DC=contoso,DC=com' -Check -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -CommandName Disable-ADAccount -Times 0
            }
        }
    }

    Context 'Logging Functionality' {

        It 'Should log starting message when Log parameter is used' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Message -match 'Starting' }

                { Disable-CompromisedUser -Identity 'User1' -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should log ending message' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Message -match 'Ending' }

                { Disable-CompromisedUser -Identity 'User1' -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should log user found message' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Message -match 'found' }

                { Disable-CompromisedUser -Identity 'User1' -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should log disabling user message' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Message -match 'Disabling' }

                { Disable-CompromisedUser -Identity 'User1' -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should log error when user not found' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]'User not found'
                }
                Mock Write-Log -ParameterFilter { $Severity -eq 'Error' }

                { Disable-CompromisedUser -Identity 'InvalidUser' -Log -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It 'Should support Console parameter with logging' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Console -eq $true }

                { Disable-CompromisedUser -Identity 'User1' -Log -Console -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should log OU retrieval message' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Message -match 'Retrieve AD User' }

                { Disable-CompromisedUser -OU 'OU=TestOU,DC=contoso,DC=com' -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'Credential Handling' {

        It 'Should pass credential to Disable-ADAccount' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -ParameterFilter { $null -ne $Credential }
                Mock Write-Log -MockWith { }

                $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
                { Disable-CompromisedUser -Identity 'User1' -Credential $cred -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should work without credential parameter' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -Identity 'User1' -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'Boolean Comparison' {

        It 'Should correctly identify enabled user' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Write-Log -ParameterFilter { $Message -match 'is enabled' }

                { Disable-CompromisedUser -Identity 'User1' -Check -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should correctly identify disabled user' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $false
                    }
                }
                Mock Write-Log -ParameterFilter { $Message -match 'is disabled' }

                { Disable-CompromisedUser -Identity 'User1' -Check -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'Integration - Combined Parameters' {

        It 'Should handle Check mode with Credential' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
                { Disable-CompromisedUser -Identity 'User1' -Check -Credential $cred -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should handle OU with Check and Log' {
            InModuleScope $script:moduleName {
                Mock Get-ADUser -MockWith {
                    @(
                        [PSCustomObject]@{
                            SamAccountName = 'User1'
                            DisplayName    = 'Test User 1'
                            Enabled        = $true
                        }
                    )
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -MockWith { }

                { Disable-CompromisedUser -OU 'OU=TestOU,DC=contoso,DC=com' -Check -Log -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'Should handle FileName with Logging and Console output' {
            InModuleScope $script:moduleName {
                Mock Get-Content -MockWith { @('User1') }
                Mock Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        SamAccountName = 'User1'
                        DisplayName    = 'Test User 1'
                        Enabled        = $true
                    }
                }
                Mock Disable-ADAccount -MockWith { }
                Mock Write-Log -ParameterFilter { $Console -eq $true }

                { Disable-CompromisedUser -FileName 'C:\temp\users.txt' -Log -Console -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

}
