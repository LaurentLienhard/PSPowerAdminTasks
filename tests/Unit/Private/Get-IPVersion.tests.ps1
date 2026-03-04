BeforeAll {
    $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    $modulePath = "$projectRoot/output/module/PSPowerAdminTasks"

    if (-not (Test-Path -Path $modulePath))
    {
        Write-Error "Module not found at $modulePath. Build the module first."
    }

    Import-Module "$modulePath/PSPowerAdminTasks.psd1" -Force
}

Describe 'Get-IPVersion' {
    Context "IPv4 detection" {
        It "Should detect IPv4 from IP address" {
            Get-IPVersion -IPAddressOrSubnet "10.0.0.1" | Should -Be "IPv4"
        }

        It "Should detect IPv4 from CIDR subnet" {
            Get-IPVersion -IPAddressOrSubnet "10.0.0.0/8" | Should -Be "IPv4"
        }

        It "Should detect IPv4 from /32 subnet" {
            Get-IPVersion -IPAddressOrSubnet "192.168.1.100/32" | Should -Be "IPv4"
        }

        It "Should detect IPv4 from /24 subnet" {
            Get-IPVersion -IPAddressOrSubnet "172.16.0.0/24" | Should -Be "IPv4"
        }
    }

    Context "IPv6 detection" {
        It "Should detect IPv6 from IP address" {
            Get-IPVersion -IPAddressOrSubnet "2001:db8::1" | Should -Be "IPv6"
        }

        It "Should detect IPv6 from CIDR subnet" {
            Get-IPVersion -IPAddressOrSubnet "2001:db8::/32" | Should -Be "IPv6"
        }

        It "Should detect IPv6 from /128 subnet" {
            Get-IPVersion -IPAddressOrSubnet "2001:db8::1/128" | Should -Be "IPv6"
        }

        It "Should detect IPv6 from /0 subnet" {
            Get-IPVersion -IPAddressOrSubnet "::/0" | Should -Be "IPv6"
        }

        It "Should handle IPv6 uppercase" {
            Get-IPVersion -IPAddressOrSubnet "2001:DB8::/32" | Should -Be "IPv6"
        }
    }

    Context "Error handling" {
        It "Should return Invalid for invalid IP" {
            Get-IPVersion -IPAddressOrSubnet "invalid" | Should -Be "Invalid"
        }

        It "Should return Invalid for malformed CIDR" {
            Get-IPVersion -IPAddressOrSubnet "10.0.0.0/invalid" | Should -Be "Invalid"
        }

        It "Should return Invalid for empty string" {
            Get-IPVersion -IPAddressOrSubnet "" | Should -Be "Invalid"
        }
    }
}
