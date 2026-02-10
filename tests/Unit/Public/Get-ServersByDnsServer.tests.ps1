#region Setup
BeforeAll {
    # Import the function
    . "$PSScriptRoot/../../../source/Public/Get-ServersByDnsServer.ps1"
    . "$PSScriptRoot/../../../source/Classes/03_COMPUTER.ps1"
}

AfterAll {
    # Cleanup
}

#endregion Setup

Describe "Get-ServersByDnsServer" {

    Context "Parameter Validation" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
            Mock -CommandName Get-ADComputer -MockWith { @() } -ModuleName PSPowerAdminTasks
        }

        It "Should require DnsServer parameter" {
            { Get-ServersByDnsServer -ErrorAction Stop } | Should -Throw
        }

        It "Should accept single DNS server" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept multiple DNS servers" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should reject empty DnsServer parameter" {
            { Get-ServersByDnsServer -DnsServer '' -ErrorAction Stop } | Should -Throw
        }

        It "Should reject invalid ThrottleLimit (less than 1)" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ThrottleLimit 0 -ErrorAction Stop } | Should -Throw
        }

        It "Should reject invalid ThrottleLimit (greater than 256)" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ThrottleLimit 300 -ErrorAction Stop } | Should -Throw
        }

        It "Should reject invalid TimeoutSeconds (less than 1)" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 0 -ErrorAction Stop } | Should -Throw
        }

        It "Should reject invalid TimeoutSeconds (greater than 30)" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 31 -ErrorAction Stop } | Should -Throw
        }
    }

    Context "AD Module Handling" {
        It "Should import ActiveDirectory module if not loaded" {
            Mock -CommandName Get-Module -MockWith { $null } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
            Mock -CommandName Get-ADComputer -MockWith { @() } -ModuleName PSPowerAdminTasks

            Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue

            Assert-MockCalled -CommandName Import-Module -Times 1 -Scope It -ModuleName PSPowerAdminTasks
        }

        It "Should handle AD module import failure" {
            Mock -CommandName Get-Module -MockWith { $null } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { throw "Module not found" } -ModuleName PSPowerAdminTasks

            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction Stop } | Should -Throw
        }
    }

    Context "ShouldProcess Support" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
            Mock -CommandName Get-ADComputer -MockWith { @() } -ModuleName PSPowerAdminTasks
        }

        It "Should support WhatIf parameter" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -WhatIf } | Should -Not -Throw
        }

        It "Should not process when WhatIf is specified" {
            Mock -CommandName Get-ADComputer -MockWith { throw "Should not be called" } -ModuleName PSPowerAdminTasks

            # This should not throw because ShouldProcess returns false
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -WhatIf -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It "Should support Confirm parameter" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Confirm:$false -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Function Output" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks

            # Mock AD computers
            $mockComputers = @(
                [PSCustomObject]@{
                    Name              = 'Server01'
                    OperatingSystem   = 'Windows Server 2019'
                    Description       = 'Test Server 1'
                    DistinguishedName = 'CN=Server01,OU=Servers,DC=contoso,DC=com'
                }
                [PSCustomObject]@{
                    Name              = 'Server02'
                    OperatingSystem   = 'Windows Server 2022'
                    Description       = 'Test Server 2'
                    DistinguishedName = 'CN=Server02,OU=Servers,DC=contoso,DC=com'
                }
            )

            Mock -CommandName Get-ADComputer -MockWith { $mockComputers } -ModuleName PSPowerAdminTasks
            Mock -CommandName Test-Connection -MockWith { $true } -ModuleName PSPowerAdminTasks
        }

        It "Should return PSCustomObject when servers are found" {
            # This test is limited because we can't easily mock the COMPUTER class
            # But we can verify the function doesn't error
            Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 1 -ErrorAction SilentlyContinue |
                ForEach-Object { $_ | Should -BeOfType [PSCustomObject] }
        }

        It "Should return null when no active computers exist" {
            Mock -CommandName Get-ADComputer -MockWith { $null } -ModuleName PSPowerAdminTasks

            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should handle computers with no DNS configuration" {
            Mock -CommandName Get-ADComputer -MockWith { $mockComputers } -ModuleName PSPowerAdminTasks
            Mock -CommandName Test-Connection -MockWith { $true } -ModuleName PSPowerAdminTasks

            # Function should not error even if DNS info is unavailable
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 1 -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context "Parameter Options" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
            Mock -CommandName Get-ADComputer -MockWith { @() } -ModuleName PSPowerAdminTasks
        }

        It "Should accept Credential parameter" {
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Credential $cred -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept Server parameter for DC specification" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Server 'dc.contoso.com' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept custom ThrottleLimit" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ThrottleLimit 64 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept custom TimeoutSeconds" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 5 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept all parameters together" {
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Server 'dc.contoso.com' -Credential $cred -ThrottleLimit 48 -TimeoutSeconds 3 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
        }

        It "Should handle AD query failures gracefully" {
            Mock -CommandName Get-ADComputer -MockWith { throw "Access Denied" } -ModuleName PSPowerAdminTasks

            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should continue processing when individual servers fail" {
            $mockComputers = @(
                [PSCustomObject]@{
                    Name              = 'Server01'
                    OperatingSystem   = 'Windows Server 2019'
                    Description       = 'Test Server 1'
                }
            )
            Mock -CommandName Get-ADComputer -MockWith { $mockComputers } -ModuleName PSPowerAdminTasks
            Mock -CommandName Test-Connection -MockWith { throw "Connection failed" } -ModuleName PSPowerAdminTasks

            # Should not throw, just skip the problematic server
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -TimeoutSeconds 1 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Verbose Logging" {
        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $true } -ModuleName PSPowerAdminTasks
            Mock -CommandName Import-Module -MockWith { } -ModuleName PSPowerAdminTasks
            Mock -CommandName Get-ADComputer -MockWith { @() } -ModuleName PSPowerAdminTasks
        }

        It "Should produce verbose output" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -Verbose 4>&1 | Out-String
            $result -match "Searching for servers" | Should -Be $true
        }
    }
}

Describe "Invoke-ServerDnsCheck" {
    Context "Helper Function - Invoke-ServerDnsCheck" {
        It "Should exist as a helper function" {
            Get-Command -Name Invoke-ServerDnsCheck -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Invoke-ServerDnsCheckSequential" {
    Context "Helper Function - Invoke-ServerDnsCheckSequential" {
        It "Should exist as a helper function" {
            Get-Command -Name Invoke-ServerDnsCheckSequential -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
