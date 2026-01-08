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

Describe 'Get-EffectiveADAccess' -Tag 'Unit' {

    Context 'Parameter Acceptance' {

        It 'Should accept Identity and Principal parameters' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name                 = 'TestUser'
                    SamAccountName       = 'testuser'
                    UserPrincipalName    = 'testuser@contoso.com'
                    DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                    ObjectClass          = 'user'
                    SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                }
            }
            Mock -CommandName Get-ACL -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Access = $null
                }
            }

            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept Server parameter' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -ParameterFilter { $null -ne $Server } -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -ParameterFilter { $null -ne $Server } -MockWith {
                [PSCustomObject]@{
                    Name                 = 'TestUser'
                    SamAccountName       = 'testuser'
                    UserPrincipalName    = 'testuser@contoso.com'
                    DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                    ObjectClass          = 'user'
                    SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                }
            }
            Mock -CommandName Get-ACL -ModuleName $script:moduleName -ParameterFilter { $null -ne $Server } -MockWith { $null }

            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -Server 'DC01' -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept Credential parameter' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -MockWith {
                [PSCustomObject]@{
                    Name                 = 'TestUser'
                    SamAccountName       = 'testuser'
                    UserPrincipalName    = 'testuser@contoso.com'
                    DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                    ObjectClass          = 'user'
                    SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                }
            }
            Mock -CommandName Get-ACL -ModuleName $script:moduleName -ParameterFilter { $null -ne $Credential } -MockWith { $null }

            $cred = New-Object System.Management.Automation.PSCredential ('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -Credential $cred -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should accept pipeline input for Identity by property' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = $null
                    }
                }

                { [PSCustomObject]@{ DistinguishedName = 'CN=Users,DC=contoso,DC=com' } | Get-EffectiveADAccess -Principal 'testuser' -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }

    Context 'AD Object Resolution' {

        It 'Should resolve AD object by Distinguished Name' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = $null
                    }
                }

                Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue
                Should -Invoke -CommandName Get-ADObject -Times 1
            }
        }

        It 'Should throw when AD object not found' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith { $null }

            { Get-EffectiveADAccess -Identity 'CN=NonExistent,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*Could not find AD object*'
        }
    }

    Context 'Principal Resolution' {

        It 'Should resolve user principal' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = $null
                    }
                }

                Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue
                Should -Invoke -CommandName Get-ADUser -Times 1
            }
        }

        It 'Should resolve group principal when user resolution fails' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith { throw 'User not found' }
                Mock -CommandName Get-ADGroup -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'Domain Admins'
                        SamAccountName       = 'Domain Admins'
                        DistinguishedName    = 'CN=Domain Admins,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'group'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-512'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = $null
                    }
                }

                Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'Domain Admins' -ErrorAction SilentlyContinue
                Should -Invoke -CommandName Get-ADGroup -Times 1
            }
        }

        It 'Should throw when principal cannot be resolved' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith { throw 'User not found' }
            Mock -CommandName Get-ADGroup -ModuleName $script:moduleName -MockWith { throw 'Group not found' }

            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'NonExistent' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*Could not resolve principal*'
        }
    }

    Context 'ACL Retrieval' {

        It 'Should retrieve security descriptor from target object' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = $null
                    }
                }

                Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue
                Should -Invoke -CommandName Get-ACL -Times 1
            }
        }

        It 'Should warn when no security descriptor found' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name                 = 'TestUser'
                    SamAccountName       = 'testuser'
                    UserPrincipalName    = 'testuser@contoso.com'
                    DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                    ObjectClass          = 'user'
                    SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                }
            }
            Mock -CommandName Get-ACL -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Access = $null
                }
            }

            Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue -WarningVariable warning
            $warning | Should -Contain 'No security descriptor found'
        }
    }

    Context 'Permission Processing' {

        It 'Should return permissions matching principal SamAccountName' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'CONTOSO\testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = @(
                            [PSCustomObject]@{
                                IdentityReference = 'CONTOSO\testuser'
                                AccessControlType = 'Allow'
                                ActiveDirectoryRights = 'ReadProperty'
                                InheritanceFlags = 'None'
                                PropagationFlags = 'None'
                                IsInherited = $false
                                ObjectType = [System.Guid]::Empty
                                InheritedObjectType = [System.Guid]::Empty
                            }
                        )
                    }
                }

                $result = Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue

                $result | Should -Not -BeNullOrEmpty
                $result[0].IdentityReference | Should -Be 'CONTOSO\testuser'
            }
        }

        It 'Should return empty result when no matching permissions' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = @(
                            [PSCustomObject]@{
                                IdentityReference = 'CONTOSO\otheruser'
                                AccessControlType = 'Allow'
                                ActiveDirectoryRights = 'ReadProperty'
                                InheritanceFlags = 'None'
                                PropagationFlags = 'None'
                                IsInherited = $false
                                ObjectType = [System.Guid]::Empty
                                InheritedObjectType = [System.Guid]::Empty
                            }
                        )
                    }
                }
                Mock -CommandName Get-ADPrincipalGroupMembership -MockWith { $null }

                $result = Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue

                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Output Structure' {

        It 'Should return PSCustomObject with all expected properties' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'CONTOSO\testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = @(
                            [PSCustomObject]@{
                                IdentityReference = 'CONTOSO\testuser'
                                AccessControlType = 'Allow'
                                ActiveDirectoryRights = 'ReadProperty'
                                InheritanceFlags = 'None'
                                PropagationFlags = 'None'
                                IsInherited = $false
                                ObjectType = [System.Guid]::Empty
                                InheritedObjectType = [System.Guid]::Empty
                            }
                        )
                    }
                }

                $result = Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue

                $result | Should -HaveProperty 'ADObject'
                $result | Should -HaveProperty 'Principal'
                $result | Should -HaveProperty 'PrincipalType'
                $result | Should -HaveProperty 'IdentityReference'
                $result | Should -HaveProperty 'AccessControlType'
                $result | Should -HaveProperty 'ActiveDirectoryRights'
                $result | Should -HaveProperty 'InheritanceFlags'
                $result | Should -HaveProperty 'PropagationFlags'
                $result | Should -HaveProperty 'IsInherited'
                $result | Should -HaveProperty 'ObjectType'
                $result | Should -HaveProperty 'InheritedObjectType'
            }
        }

        It 'Should have correct principal and AD object in output' {
            InModuleScope $script:moduleName {
                Mock -CommandName Get-ADObject -MockWith {
                    [PSCustomObject]@{
                        DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                    }
                }
                Mock -CommandName Get-ADUser -MockWith {
                    [PSCustomObject]@{
                        Name                 = 'TestUser'
                        SamAccountName       = 'CONTOSO\testuser'
                        UserPrincipalName    = 'testuser@contoso.com'
                        DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                        ObjectClass          = 'user'
                        SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                    }
                }
                Mock -CommandName Get-ACL -MockWith {
                    [PSCustomObject]@{
                        Access = @(
                            [PSCustomObject]@{
                                IdentityReference = 'CONTOSO\testuser'
                                AccessControlType = 'Allow'
                                ActiveDirectoryRights = 'ReadProperty'
                                InheritanceFlags = 'None'
                                PropagationFlags = 'None'
                                IsInherited = $false
                                ObjectType = [System.Guid]::Empty
                                InheritedObjectType = [System.Guid]::Empty
                            }
                        )
                    }
                }

                $result = Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction SilentlyContinue

                $result.ADObject | Should -Be 'CN=Users,DC=contoso,DC=com'
                $result.Principal | Should -Be 'TestUser'
                $result.PrincipalType | Should -Be 'user'
            }
        }
    }

    Context 'Error Handling' {

        It 'Should handle Get-ADObject errors gracefully' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith { throw 'Access denied' }

            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -ErrorAction Stop } | Should -Throw
        }

        It 'Should support Verbose parameter' {
            Mock -CommandName Get-ADObject -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    DistinguishedName = 'CN=Users,DC=contoso,DC=com'
                }
            }
            Mock -CommandName Get-ADUser -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Name                 = 'TestUser'
                    SamAccountName       = 'testuser'
                    UserPrincipalName    = 'testuser@contoso.com'
                    DistinguishedName    = 'CN=TestUser,CN=Users,DC=contoso,DC=com'
                    ObjectClass          = 'user'
                    SID                  = 'S-1-5-21-3623811015-3361044348-30300820-1013'
                }
            }
            Mock -CommandName Get-ACL -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Access = $null
                }
            }

            { Get-EffectiveADAccess -Identity 'CN=Users,DC=contoso,DC=com' -Principal 'testuser' -Verbose -ErrorAction SilentlyContinue 4>&1 } | Should -Not -Throw
        }
    }

}
