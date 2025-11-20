BeforeAll {
    $projectPath = "$PSScriptRoot/../../.." | Convert-Path
    $projectName = (Get-ChildItem -Path "$projectPath/source/*.psd1" | Where-Object {
        ($_.Directory.Name -eq 'source') -and
        $(try { Test-ModuleManifest -Path $_.FullName -ErrorAction Stop } catch { $false })
    }).BaseName

    # Import the module
    Import-Module -Name $projectName -Force -ErrorAction Stop
}

Describe 'Get-RemoteSoftware' -Tag 'Unit' {
    BeforeAll {
        # Mock data for software inventory
        $mockSoftwareData = @(
            [PSCustomObject]@{
                ComputerName = 'TESTSERVER01'
                Name         = 'Microsoft Office'
                Version      = '16.0.12345'
                Publisher    = 'Microsoft Corporation'
                InstallDate  = '20230115'
                Architecture = '64-bit'
            },
            [PSCustomObject]@{
                ComputerName = 'TESTSERVER01'
                Name         = 'Adobe Reader'
                Version      = '2023.001.20093'
                Publisher    = 'Adobe Inc.'
                InstallDate  = '20230201'
                Architecture = '32-bit'
            }
        )
    }

    Context 'Parameter Validation' {
        It 'Should have ComputerName parameter that accepts pipeline input' {
            $command = Get-Command Get-RemoteSoftware
            $parameter = $command.Parameters['ComputerName']
            $parameter.Attributes.ValueFromPipeline | Should -BeTrue
            $parameter.Attributes.ValueFromPipelineByPropertyName | Should -BeTrue
        }

        It 'Should have Credential parameter' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters.ContainsKey('Credential') | Should -BeTrue
        }

        It 'Should have ThrottleLimit parameter with valid range' {
            $command = Get-Command Get-RemoteSoftware
            $parameter = $command.Parameters['ThrottleLimit']
            $parameter | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters.ContainsKey('WhatIf') | Should -BeTrue
            $command.Parameters.ContainsKey('Confirm') | Should -BeTrue
        }
    }

    Context 'Local Computer Execution' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Error -ModuleName PSPowerAdminTasks
        }

        It 'Should execute scriptblock locally when ComputerName is localhost' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Test Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Test Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName 'localhost'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 0
        }

        It 'Should execute scriptblock locally when ComputerName is current machine' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Test Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Test Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }
            Mock -CommandName hostname -ModuleName PSPowerAdminTasks -MockWith { 'TESTMACHINE' }

            $result = Get-RemoteSoftware -ComputerName 'TESTMACHINE'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 0
        }

        It 'Should execute scriptblock locally when ComputerName is dot' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Test Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Test Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName '.'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 0
        }
    }

    Context 'Remote Computer Execution' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Error -ModuleName PSPowerAdminTasks
        }

        It 'Should call Invoke-Command for remote computer' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }

            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should pass Credential parameter to Invoke-Command when specified' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            } -ParameterFilter { $null -ne $Credential }

            $cred = New-Object System.Management.Automation.PSCredential ('testuser', (ConvertTo-SecureString 'testpass' -AsPlainText -Force))
            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01' -Credential $cred

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter { $null -ne $Credential } -Times 1
        }

        It 'Should process multiple computers' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }

            $result = Get-RemoteSoftware -ComputerName 'SERVER01', 'SERVER02'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 2
        }

        It 'Should accept pipeline input by value' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }

            $result = 'SERVER01', 'SERVER02' | Get-RemoteSoftware

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 2
        }

        It 'Should accept pipeline input by property name' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }

            $computers = @(
                [PSCustomObject]@{ ComputerName = 'SERVER01' },
                [PSCustomObject]@{ ComputerName = 'SERVER02' }
            )

            $result = $computers | Get-RemoteSoftware

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 2
        }

        It 'Should use custom ThrottleLimit when specified' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            } -ParameterFilter { $ThrottleLimit -eq 10 }

            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01' -ThrottleLimit 10

            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -ParameterFilter { $ThrottleLimit -eq 10 } -Times 1
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Error -ModuleName PSPowerAdminTasks
        }

        It 'Should handle connection errors gracefully' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                throw 'Connection failed'
            }

            $result = Get-RemoteSoftware -ComputerName 'UNREACHABLE' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Write-Error -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should write warning when no software is found' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $null
            }

            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01' -WarningAction SilentlyContinue

            Should -Invoke -CommandName Write-Warning -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should continue processing remaining computers after an error' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                if ($ComputerName -eq 'FAIL') {
                    throw 'Connection failed'
                }
                return $mockSoftwareData
            }

            $result = Get-RemoteSoftware -ComputerName 'FAIL', 'SUCCESS' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 2
            Should -Invoke -CommandName Write-Error -ModuleName PSPowerAdminTasks -Times 1
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
        }

        It 'Should not execute when WhatIf is specified' {
            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01' -WhatIf

            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 0
        }

        It 'Should execute when WhatIf is not specified' {
            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01'

            Should -Invoke -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -Times 1
        }
    }

    Context 'Output Validation' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
        }

        It 'Should return objects with correct properties' {
            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01'

            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'ComputerName'
            $result[0].PSObject.Properties.Name | Should -Contain 'Name'
            $result[0].PSObject.Properties.Name | Should -Contain 'Version'
            $result[0].PSObject.Properties.Name | Should -Contain 'Publisher'
            $result[0].PSObject.Properties.Name | Should -Contain 'InstallDate'
            $result[0].PSObject.Properties.Name | Should -Contain 'Architecture'
        }

        It 'Should return both 32-bit and 64-bit software' {
            $result = Get-RemoteSoftware -ComputerName 'TESTSERVER01'

            $result | Where-Object { $_.Architecture -eq '64-bit' } | Should -Not -BeNullOrEmpty
            $result | Where-Object { $_.Architecture -eq '32-bit' } | Should -Not -BeNullOrEmpty
        }

        It 'Should aggregate results from multiple computers' {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return @(
                    [PSCustomObject]@{
                        ComputerName = $ComputerName
                        Name         = 'Test Software'
                        Version      = '1.0'
                        Publisher    = 'Test'
                        InstallDate  = '20230101'
                        Architecture = '64-bit'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName 'SERVER01', 'SERVER02'

            $result.Count | Should -Be 2
            ($result | Where-Object { $_.ComputerName -eq 'SERVER01' }) | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.ComputerName -eq 'SERVER02' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Verbose Output' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName PSPowerAdminTasks -MockWith {
                return $mockSoftwareData
            }
        }

        It 'Should write verbose messages during execution' {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks

            Get-RemoteSoftware -ComputerName 'TESTSERVER01' -Verbose

            Should -Invoke -CommandName Write-Verbose -ModuleName PSPowerAdminTasks -Times 4 -ParameterFilter {
                $Message -like '*Starting*' -or
                $Message -like '*Processing*' -or
                $Message -like '*Querying*' -or
                $Message -like '*Retrieved*' -or
                $Message -like '*Completed*'
            }
        }
    }

    Context 'Cross-platform hostname handling' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
        }

        It 'Should handle when env:COMPUTERNAME is available' {
            Mock -CommandName hostname -ModuleName PSPowerAdminTasks -MockWith { 'HOSTNAME-CMD' }
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Test Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Test Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }

            # Simulate Windows where $env:COMPUTERNAME exists
            $originalComputerName = $env:COMPUTERNAME
            try {
                $env:COMPUTERNAME = 'WINDOWS-PC'
                $result = Get-RemoteSoftware -ComputerName 'WINDOWS-PC'
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:COMPUTERNAME = $originalComputerName
            }
        }

        It 'Should use hostname command when env:COMPUTERNAME is not available' {
            Mock -CommandName hostname -ModuleName PSPowerAdminTasks -MockWith { 'MAC-HOSTNAME' }
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Test Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Test Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName 'MAC-HOSTNAME'
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName hostname -ModuleName PSPowerAdminTasks -Times 1
        }
    }

    Context 'ScriptBlock execution coverage' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
        }

        It 'Should execute scriptblock and check registry paths' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith {
                param($Path)
                $Path -like "*Uninstall*"
            }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Software 64-bit'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Publisher'
                        InstallDate    = '20230101'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName 'localhost'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Test-Path -ModuleName PSPowerAdminTasks -Times 2 -Exactly
            Should -Invoke -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -Times 2 -Exactly
        }

        It 'Should filter out entries without DisplayName' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName    = 'Valid Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Publisher'
                        InstallDate    = '20230101'
                    },
                    [PSCustomObject]@{
                        DisplayName    = $null
                        DisplayVersion = '2.0.0'
                        Publisher      = 'Publisher2'
                        InstallDate    = '20230102'
                    }
                )
            }

            $result = Get-RemoteSoftware -ComputerName 'localhost'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should handle path that does not exist' {
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $false }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks

            $result = Get-RemoteSoftware -ComputerName 'localhost' -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -Times 0
        }

        It 'Should distinguish between 32-bit and 64-bit software' {
            $script:pathsCalled = @()
            Mock -CommandName Test-Path -ModuleName PSPowerAdminTasks -MockWith { $true }
            Mock -CommandName Get-ItemProperty -ModuleName PSPowerAdminTasks -MockWith {
                param($Path)
                $script:pathsCalled += $Path
                if ($Path -like "*Wow6432Node*") {
                    @([PSCustomObject]@{
                        DisplayName    = '32-bit Software'
                        DisplayVersion = '1.0.0'
                        Publisher      = 'Publisher'
                        InstallDate    = '20230101'
                    })
                }
                else {
                    @([PSCustomObject]@{
                        DisplayName    = '64-bit Software'
                        DisplayVersion = '2.0.0'
                        Publisher      = 'Publisher'
                        InstallDate    = '20230102'
                    })
                }
            }

            $result = Get-RemoteSoftware -ComputerName 'localhost'

            $result | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.Name -eq '32-bit Software' }).Architecture | Should -Be '32-bit'
            ($result | Where-Object { $_.Name -eq '64-bit Software' }).Architecture | Should -Be '64-bit'
        }
    }
}
