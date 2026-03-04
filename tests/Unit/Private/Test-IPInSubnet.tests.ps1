BeforeAll {
    $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    $modulePath = "$projectRoot/output/module/PSPowerAdminTasks"

    if (-not (Test-Path -Path $modulePath))
    {
        Write-Error "Module not found at $modulePath. Build the module first."
    }

    Import-Module "$modulePath/PSPowerAdminTasks.psd1" -Force
}

Describe 'Test-IPInSubnet' {
    Context "IPv4 validation" {
        It "Should return true for IP in subnet" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "10.0.0.0/24" | Should -Be $true
        }

        It "Should return true for network address" {
            Test-IPInSubnet -IPAddress "10.0.0.0" -Subnet "10.0.0.0/24" | Should -Be $true
        }

        It "Should return true for broadcast address" {
            Test-IPInSubnet -IPAddress "10.0.0.255" -Subnet "10.0.0.0/24" | Should -Be $true
        }

        It "Should return false for IP outside subnet" {
            Test-IPInSubnet -IPAddress "10.0.1.5" -Subnet "10.0.0.0/24" | Should -Be $false
        }

        It "Should handle /32 subnet (single host)" {
            Test-IPInSubnet -IPAddress "192.168.1.100" -Subnet "192.168.1.100/32" | Should -Be $true
            Test-IPInSubnet -IPAddress "192.168.1.101" -Subnet "192.168.1.100/32" | Should -Be $false
        }

        It "Should handle /0 subnet (all addresses)" {
            Test-IPInSubnet -IPAddress "1.1.1.1" -Subnet "0.0.0.0/0" | Should -Be $true
            Test-IPInSubnet -IPAddress "255.255.255.255" -Subnet "0.0.0.0/0" | Should -Be $true
        }

        It "Should handle /16 subnet" {
            Test-IPInSubnet -IPAddress "172.16.5.100" -Subnet "172.16.0.0/16" | Should -Be $true
            Test-IPInSubnet -IPAddress "172.17.5.100" -Subnet "172.16.0.0/16" | Should -Be $false
        }

        It "Should handle /8 subnet" {
            Test-IPInSubnet -IPAddress "10.255.255.255" -Subnet "10.0.0.0/8" | Should -Be $true
            Test-IPInSubnet -IPAddress "11.0.0.0" -Subnet "10.0.0.0/8" | Should -Be $false
        }
    }

    Context "IPv6 validation" {
        It "Should return true for IPv6 in subnet" {
            Test-IPInSubnet -IPAddress "2001:db8::1" -Subnet "2001:db8::/32" | Should -Be $true
        }

        It "Should return false for IPv6 outside subnet" {
            Test-IPInSubnet -IPAddress "2001:db9::1" -Subnet "2001:db8::/32" | Should -Be $false
        }

        It "Should handle /128 subnet (single host)" {
            Test-IPInSubnet -IPAddress "2001:db8::1" -Subnet "2001:db8::1/128" | Should -Be $true
            Test-IPInSubnet -IPAddress "2001:db8::2" -Subnet "2001:db8::1/128" | Should -Be $false
        }

        It "Should handle /0 subnet (all addresses)" {
            Test-IPInSubnet -IPAddress "2001:db8::1" -Subnet "::/0" | Should -Be $true
        }
    }

    Context "Error handling" {
        It "Should return false for invalid subnet format" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "10.0.0.0" | Should -Be $false
        }

        It "Should return false for invalid IP address" {
            Test-IPInSubnet -IPAddress "invalid" -Subnet "10.0.0.0/24" | Should -Be $false
        }

        It "Should return false for invalid subnet address" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "invalid/24" | Should -Be $false
        }

        It "Should return false for IPv4 prefix length > 32" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "10.0.0.0/33" | Should -Be $false
        }

        It "Should return false for IPv6 prefix length > 128" {
            Test-IPInSubnet -IPAddress "2001:db8::1" -Subnet "2001:db8::/129" | Should -Be $false
        }

        It "Should return false for mixed address families" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "2001:db8::/32" | Should -Be $false
        }

        It "Should return false for negative prefix length" {
            Test-IPInSubnet -IPAddress "10.0.0.5" -Subnet "10.0.0.0/-1" | Should -Be $false
        }
    }

    Context "Edge cases" {
        It "Should handle leading zeros in IPv4" {
            Test-IPInSubnet -IPAddress "10.000.000.005" -Subnet "10.0.0.0/24" | Should -Be $true
        }

        It "Should handle different case for IPv6" {
            Test-IPInSubnet -IPAddress "2001:DB8::1" -Subnet "2001:db8::/32" | Should -Be $true
        }
    }
}
