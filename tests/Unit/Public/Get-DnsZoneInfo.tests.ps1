BeforeAll {
    $projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    $modulePath = "$projectRoot/output/module/PSPowerAdminTasks"

    if (-not (Test-Path -Path $modulePath))
    {
        Write-Error "Module not found at $modulePath. Build the module first."
    }

    Import-Module "$modulePath/PSPowerAdminTasks.psd1" -Force
}

Describe 'Get-DnsZoneInfo' {
    BeforeEach {
        $mockComputerName = "DNS01"
        $mockZoneName = "contoso.com"
        $mockCredential = [System.Management.Automation.PSCredential]::new("domain\user", (ConvertTo-SecureString "password" -AsPlainText -Force))
    }

    Context "Basic functionality" {
        It "Should accept ComputerName parameter" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept pipeline input for ComputerName" {
            { $mockComputerName | Get-DnsZoneInfo -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept ZoneName parameter" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept Credential parameter" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -Credential $mockCredential -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept ThrottleLimit parameter" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ThrottleLimit 64 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Parameter validation" {
        It "Should require ComputerName parameter" {
            { Get-DnsZoneInfo -ErrorAction Stop } | Should -Throw
        }

        It "Should validate ThrottleLimit range (minimum 1)" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ThrottleLimit 0 -ErrorAction Stop } | Should -Throw
        }

        It "Should validate ThrottleLimit range (maximum 256)" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ThrottleLimit 257 -ErrorAction Stop } | Should -Throw
        }

        It "Should accept valid ThrottleLimit values" {
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ThrottleLimit 1 -ErrorAction SilentlyContinue } | Should -Not -Throw
            { Get-DnsZoneInfo -ComputerName $mockComputerName -ThrottleLimit 256 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "DNS class integration" {
        It "Should create DNS class instance without credentials" {
            Mock -CommandName New-CimSession -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{
                    ComputerName = $mockComputerName
                }
            }

            Mock -CommandName Get-DnsServerZone -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{
                    ZoneName = $mockZoneName
                    ZoneType = "Primary"
                }
            }

            Mock -CommandName Get-DnsServerResourceRecord -ModuleName PSPowerAdminTasks -MockWith {
                return @()
            }

            Mock -CommandName Remove-CimSession -ModuleName PSPowerAdminTasks -MockWith { }

            { Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName } | Should -Not -Throw
        }
    }

    Context "Output format" {
        BeforeEach {
            Mock -CommandName New-CimSession -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{ ComputerName = $mockComputerName }
            }

            Mock -CommandName Get-DnsServerZone -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{
                    ZoneName = $mockZoneName
                    ZoneType = "Primary"
                }
            }

            Mock -CommandName Get-DnsServerResourceRecord -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        HostName   = "server01"
                        RecordType = "A"
                        RecordData = @{ IPv4Address = @{ IPAddressToString = "192.168.1.10" } }
                        TTL        = 3600
                        Timestamp  = $null
                    },
                    [PSCustomObject]@{
                        HostName   = "mail"
                        RecordType = "MX"
                        RecordData = @{ Preference = 10; MailExchange = "mail.contoso.com" }
                        TTL        = 3600
                        Timestamp  = [datetime]"2024-01-01"
                    }
                )
            }

            Mock -CommandName Remove-CimSession -ModuleName PSPowerAdminTasks -MockWith { }
        }

        It "Should return objects with expected properties" {
            $result = Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain "ComputerName"
            $result[0].PSObject.Properties.Name | Should -Contain "ZoneName"
            $result[0].PSObject.Properties.Name | Should -Contain "HostName"
            $result[0].PSObject.Properties.Name | Should -Contain "RecordType"
            $result[0].PSObject.Properties.Name | Should -Contain "RecordData"
            $result[0].PSObject.Properties.Name | Should -Contain "TTL"
            $result[0].PSObject.Properties.Name | Should -Contain "IsStatic"
            $result[0].PSObject.Properties.Name | Should -Contain "Timestamp"
        }

        It "Should handle A records correctly" {
            $result = @(Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName)
            $aRecord = $result | Where-Object { $_.RecordType -eq "A" }
            $aRecord.RecordData | Should -Be "192.168.1.10"
        }

        It "Should handle MX records correctly" {
            $result = @(Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName)
            $mxRecord = $result | Where-Object { $_.RecordType -eq "MX" }
            $mxRecord.RecordData | Should -Be "10 mail.contoso.com"
        }

        It "Should set IsStatic to $true for records without timestamp" {
            $result = @(Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName)
            $aRecord = $result | Where-Object { $_.RecordType -eq "A" }
            $aRecord.IsStatic | Should -Be $true
            $aRecord.Timestamp | Should -Be "Static"
        }

        It "Should set IsStatic to $false for records with timestamp" {
            $result = @(Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName)
            $mxRecord = $result | Where-Object { $_.RecordType -eq "MX" }
            $mxRecord.IsStatic | Should -Be $false
            $mxRecord.Timestamp | Should -Be ([datetime]"2024-01-01")
        }

        It "Should correctly identify static vs dynamic records" {
            $result = @(Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName $mockZoneName)
            $staticRecords = $result | Where-Object { $_.IsStatic -eq $true }
            $dynamicRecords = $result | Where-Object { $_.IsStatic -eq $false }
            $staticRecords.Count | Should -Be 1
            $dynamicRecords.Count | Should -Be 1
        }
    }

    Context "Error handling" {
        It "Should handle connection failures gracefully" {
            Mock -CommandName New-CimSession -ModuleName PSPowerAdminTasks -MockWith {
                throw "Connection failed"
            }

            { Get-DnsZoneInfo -ComputerName "unreachable-server" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle missing zones gracefully" {
            Mock -CommandName New-CimSession -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{ ComputerName = $mockComputerName }
            }

            Mock -CommandName Get-DnsServerZone -ModuleName PSPowerAdminTasks -MockWith {
                return @()
            }

            Mock -CommandName Remove-CimSession -ModuleName PSPowerAdminTasks -MockWith { }

            { Get-DnsZoneInfo -ComputerName $mockComputerName -ZoneName "nonexistent.com" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Multiple inputs" {
        BeforeEach {
            Mock -CommandName New-CimSession -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{ ComputerName = $_.ComputerName }
            }

            Mock -CommandName Get-DnsServerZone -ModuleName PSPowerAdminTasks -MockWith {
                [PSCustomObject]@{
                    ZoneName = $mockZoneName
                    ZoneType = "Primary"
                }
            }

            Mock -CommandName Get-DnsServerResourceRecord -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        HostName   = "test"
                        RecordType = "A"
                        RecordData = @{ IPv4Address = @{ IPAddressToString = "192.168.1.1" } }
                        TTL        = 3600
                        Timestamp  = $null
                    }
                )
            }

            Mock -CommandName Remove-CimSession -ModuleName PSPowerAdminTasks -MockWith { }
        }

        It "Should process multiple computer names via pipeline" {
            $computers = "DNS01", "DNS02"
            { $computers | Get-DnsZoneInfo -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should process multiple computer names via parameter" {
            { Get-DnsZoneInfo -ComputerName "DNS01", "DNS02" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}
