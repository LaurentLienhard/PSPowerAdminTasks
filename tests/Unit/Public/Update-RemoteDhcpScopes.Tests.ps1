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

Describe 'Update-RemoteDhcpScopes' -Tag 'Unit' {

    Context 'Function Availability' {

        It 'Should exist in the module' {
            Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Should be a function' {
            (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).CommandType | Should -Be 'Function'
        }
    }

    Context 'Parameter Definition' {

        It 'Should have a mandatory ScopeId parameter' {
            $param = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['ScopeId']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have a mandatory ComputerName parameter' {
            $param = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have a mandatory Credential parameter' {
            $param = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['Credential']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should have an Overwrite parameter set with DnsServers' {
            $param = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['DnsServers']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have a Replace parameter set with ReplaceDns and WithDns' {
            $paramReplace = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['ReplaceDns']
            $paramWith = (Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName).Parameters['WithDns']
            $paramReplace | Should -Not -BeNullOrEmpty
            $paramWith | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess (WhatIf)' {
            $cmd = Get-Command -Name Update-RemoteDhcpScopes -Module $script:moduleName
            $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
        }
    }

    Context 'Help Documentation' {

        It 'Should have help documentation' {
            $help = Get-Help -Name Update-RemoteDhcpScopes -ErrorAction SilentlyContinue
            $help | Should -Not -BeNullOrEmpty
        }

        It 'Should have a synopsis' {
            $help = Get-Help -Name Update-RemoteDhcpScopes -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have at least one example' {
            $help = Get-Help -Name Update-RemoteDhcpScopes -ErrorAction SilentlyContinue
            $help.Examples | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Execution - Overwrite Mode' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )
            $script:fakeCimSession = [PSCustomObject]@{ Id = 1 }

            Mock -CommandName New-CimSessionOption -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Protocol = 'WsMan' }
            }

            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                $script:fakeCimSession
            }

            Mock -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Remove-CimSession -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call New-CimSession to connect to the DHCP server' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -DnsServers '10.0.0.1', '10.0.0.2' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName New-CimSession -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should call Set-DhcpServerv4OptionValue to update DNS servers' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -DnsServers '10.0.0.1', '10.0.0.2' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should close the CIM session after processing' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -DnsServers '10.0.0.1' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName Remove-CimSession -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }

    Context 'Execution - Replace Mode' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )
            $script:fakeCimSession = [PSCustomObject]@{ Id = 1 }

            Mock -CommandName New-CimSessionOption -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Protocol = 'WsMan' }
            }

            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                $script:fakeCimSession
            }

            Mock -CommandName Get-DhcpServerv4OptionValue -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Value = @('10.0.0.1', '10.0.0.2') }
            }

            Mock -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Remove-CimSession -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should call Get-DhcpServerv4OptionValue to fetch current DNS list' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -ReplaceDns '10.0.0.1' -WithDns '10.0.0.10' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName Get-DhcpServerv4OptionValue -ModuleName $script:moduleName -Times 1 -Exactly
        }

        It 'Should call Set-DhcpServerv4OptionValue with the replaced IP' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -ReplaceDns '10.0.0.1' -WithDns '10.0.0.10' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -Times 1 -Exactly
        }
    }

    Context 'Execution - Replace Mode IP Not Found' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )
            $script:fakeCimSession = [PSCustomObject]@{ Id = 1 }

            Mock -CommandName New-CimSessionOption -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Protocol = 'WsMan' }
            }

            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                $script:fakeCimSession
            }

            Mock -CommandName Get-DhcpServerv4OptionValue -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Value = @('10.0.0.5', '10.0.0.6') }
            }

            Mock -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName Remove-CimSession -ModuleName $script:moduleName -MockWith { }
        }

        It 'Should not call Set-DhcpServerv4OptionValue when ReplaceDns IP is not found' {
            Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -ReplaceDns '10.0.0.99' -WithDns '10.0.0.10' `
                -ComputerName 'DHCP01' -Credential $script:fakeCred -Confirm:$false
            Should -Invoke -CommandName Set-DhcpServerv4OptionValue -ModuleName $script:moduleName -Times 0 -Exactly
        }
    }

    Context 'Execution - Connection Error' {

        BeforeAll {
            $script:fakeCred = [System.Management.Automation.PSCredential]::new(
                'domain\admin',
                (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)
            )

            Mock -CommandName New-CimSessionOption -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Protocol = 'WsMan' }
            }

            Mock -CommandName New-CimSession -ModuleName $script:moduleName -MockWith {
                throw 'Connection refused'
            }
        }

        It 'Should write an error when the CIM session cannot be established' {
            { Update-RemoteDhcpScopes -ScopeId '10.0.1.0' -DnsServers '10.0.0.1' `
                -ComputerName 'UNREACHABLE' -Credential $script:fakeCred -Confirm:$false `
                -ErrorAction Stop } | Should -Throw
        }
    }
}
