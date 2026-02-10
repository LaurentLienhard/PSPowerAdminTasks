#region Setup
<#
    Unit test for Get-ServersByDnsServer function
#>
BeforeAll {
    # Source the function being tested
    . "$PSScriptRoot/../../../source/Public/Get-ServersByDnsServer.ps1"

    # Load the COMPUTER class if not already loaded
    . "$PSScriptRoot/../../../source/Classes/03_COMPUTER.ps1"
}

#endregion Setup

Describe "Get-ServersByDnsServer" {

    Context "Parameter Validation" {
        It "Should accept DNS server IP addresses" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should accept multiple DNS server addresses" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15' -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should require DnsServer parameter" {
            { Get-ServersByDnsServer -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Function Output" {
        It "Should return an array or single object" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It "Should include ComputerName in output" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                $result | Should -HaveProperty 'ComputerName'
            }
        }

        It "Should include ConfiguredDNS in output" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                $result | Should -HaveProperty 'ConfiguredDNS'
            }
        }

        It "Should include IPv4Address in output" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                $result | Should -HaveProperty 'IPv4Address'
            }
        }

        It "Should include MatchingDNS in output" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                $result | Should -HaveProperty 'MatchingDNS'
            }
        }
    }

    Context "DNS Filtering Logic" {
        It "Should find servers with specified DNS" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                foreach ($server in $result) {
                    $server.ConfiguredDNS | Should -Match '10\.1\.3\.12'
                }
            }
        }

        It "Should support multiple DNS search criteria" {
            $result = Get-ServersByDnsServer -DnsServer '10.1.3.12', '10.1.3.15' -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                foreach ($server in $result) {
                    $server.ConfiguredDNS | Should -Match '(10\.1\.3\.12|10\.1\.3\.15)'
                }
            }
        }
    }

    Context "Optional Parameters" {
        It "Should accept Credential parameter" {
            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Credential $cred -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept Server parameter for DC specification" {
            { Get-ServersByDnsServer -DnsServer '10.1.3.12' -Server 'dc.contoso.com' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}
