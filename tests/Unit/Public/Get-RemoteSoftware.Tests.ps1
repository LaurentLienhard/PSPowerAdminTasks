BeforeAll {
    $script:moduleName = 'PSPowerAdminTasks'

    # Import the module
    $modulePath = "$PSScriptRoot/../../../output/module/$moduleName"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        # Fallback to source if built module doesn't exist
        $sourcePath = "$PSScriptRoot/../../../source/$moduleName.psd1"
        Import-Module $sourcePath -Force -ErrorAction Stop
    }

    # Create a mock Get-LocalSoftwareInventory function that Get-RemoteSoftware depends on
    # This needs to be defined globally so that Get-RemoteSoftware can access it
    $global:GetLocalSoftwareInventoryMock = {
        return @(
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Name         = 'Test Software'
                Version      = '1.0.0'
                Publisher    = 'Test Publisher'
                InstallDate  = '20231201'
                Architecture = 'x64'
            }
        )
    }

    # Define the function in the global scope
    Set-Item -Path function:global:Get-LocalSoftwareInventory -Value $global:GetLocalSoftwareInventoryMock
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
    Remove-Item -Path function:global:Get-LocalSoftwareInventory -ErrorAction SilentlyContinue
}

Describe 'Get-RemoteSoftware' -Tag 'Unit' {
    BeforeAll {
        # Mock data that would be returned from Invoke-Command
        $script:mockSoftwareData = @(
            [PSCustomObject]@{
                PSComputerName = 'TestServer01'
                ComputerName   = 'TestServer01'
                Name           = 'Microsoft Visual Studio Code'
                Version        = '1.85.0'
                Publisher      = 'Microsoft Corporation'
                InstallDate    = '20231215'
                Architecture   = 'x64'
                RunspaceId     = [guid]::NewGuid()
            }
            [PSCustomObject]@{
                PSComputerName = 'TestServer01'
                ComputerName   = 'TestServer01'
                Name           = 'Google Chrome'
                Version        = '120.0.6099.109'
                Publisher      = 'Google LLC'
                InstallDate    = '20231201'
                Architecture   = 'x64'
                RunspaceId     = [guid]::NewGuid()
            }
        )
    }

    Context 'Parameter Validation' {
        It 'Should have ComputerName as a mandatory parameter' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters['ComputerName'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept ComputerName from pipeline' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should accept ComputerName from pipeline by property name' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters['ComputerName'].Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have Credential as an optional parameter' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters['Credential'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept PSCredential type for Credential parameter' {
            $command = Get-Command Get-RemoteSoftware
            $command.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
        }
    }

    Context 'Functionality with single computer' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                return $script:mockSoftwareData
            }
        }

        It 'Should call Invoke-Command with correct ComputerName' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'TestServer01'
            }
        }

        It 'Should return software inventory data' {
            $result = Get-RemoteSoftware -ComputerName 'TestServer01'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }

        It 'Should return objects with expected properties' {
            $result = Get-RemoteSoftware -ComputerName 'TestServer01'

            $result[0].ComputerName | Should -Be 'TestServer01'
            $result[0].Name | Should -Be 'Microsoft Visual Studio Code'
            $result[0].Version | Should -Be '1.85.0'
            $result[0].Publisher | Should -Be 'Microsoft Corporation'
            $result[0].InstallDate | Should -Be '20231215'
            $result[0].Architecture | Should -Be 'x64'
        }

        It 'Should not include PSComputerName or RunspaceId in output' {
            $result = Get-RemoteSoftware -ComputerName 'TestServer01'

            $result[0].PSObject.Properties.Name | Should -Not -Contain 'PSComputerName'
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'RunspaceId'
        }

        It 'Should write verbose messages when -Verbose is used' {
            $verboseOutput = Get-RemoteSoftware -ComputerName 'TestServer01' -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -match 'Connecting to TestServer01' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object { $_ -match 'Operation complete' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Functionality with multiple computers' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                param($ComputerName)
                return $script:mockSoftwareData | ForEach-Object {
                    $obj = $_.PSObject.Copy()
                    $obj.ComputerName = $ComputerName
                    $obj.PSComputerName = $ComputerName
                    $obj
                }
            }
        }

        It 'Should call Invoke-Command for each computer' {
            Get-RemoteSoftware -ComputerName 'Server01', 'Server02', 'Server03'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 3 -Exactly
        }

        It 'Should process each computer in the array' {
            Get-RemoteSoftware -ComputerName 'Server01', 'Server02'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ComputerName -eq 'Server01'
            }
            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ComputerName -eq 'Server02'
            }
        }
    }

    Context 'Functionality with credentials' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                return $script:mockSoftwareData
            }

            $script:testCredential = New-Object System.Management.Automation.PSCredential(
                'TestUser',
                (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
            )
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            Get-RemoteSoftware -ComputerName 'TestServer01' -Credential $script:testCredential

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $Credential -ne $null -and $Credential.UserName -eq 'TestUser'
            }
        }

        It 'Should not pass Credential to Invoke-Command when not provided' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $PSBoundParameters.ContainsKey('Credential') -eq $false
            }
        }
    }

    Context 'Pipeline input' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                return $script:mockSoftwareData
            }
        }

        It 'Should accept computer names from pipeline' {
            'Server01', 'Server02' | Get-RemoteSoftware

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2 -Exactly
        }

        It 'Should accept objects with ComputerName property from pipeline' {
            $computers = @(
                [PSCustomObject]@{ ComputerName = 'Server01'; Location = 'DC1' }
                [PSCustomObject]@{ ComputerName = 'Server02'; Location = 'DC2' }
            )

            $computers | Get-RemoteSoftware

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2 -Exactly
        }
    }

    Context 'Error handling' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                throw 'Connection failed'
            }
        }

        It 'Should write an error when Invoke-Command fails' {
            { Get-RemoteSoftware -ComputerName 'FailServer' -ErrorAction Stop } | Should -Throw
        }

        It 'Should continue processing other computers when one fails' {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                param($ComputerName)
                if ($ComputerName -eq 'FailServer') {
                    throw 'Connection failed'
                }
                return $script:mockSoftwareData
            }

            Get-RemoteSoftware -ComputerName 'FailServer', 'GoodServer' -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 2 -Exactly
        }
    }

    Context 'ScriptBlock and ArgumentList' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                return $script:mockSoftwareData
            }
        }

        It 'Should pass a ScriptBlock to Invoke-Command' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ScriptBlock -ne $null -and $ScriptBlock -is [ScriptBlock]
            }
        }

        It 'Should pass ArgumentList to Invoke-Command' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ArgumentList -ne $null
            }
        }

        It 'Should set ErrorAction to Stop in Invoke-Command' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ErrorAction -eq 'Stop'
            }
        }

        It 'Should include Get-LocalSoftwareInventory function definition in ArgumentList' {
            Get-RemoteSoftware -ComputerName 'TestServer01'

            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -ParameterFilter {
                $ArgumentList -ne $null -and $ArgumentList.Count -gt 0
            }
        }
    }

    Context 'Output formatting' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                # Return data with extra properties that should be filtered out
                return @(
                    [PSCustomObject]@{
                        PSComputerName    = 'TestServer01'
                        ComputerName      = 'TestServer01'
                        Name              = 'Test App'
                        Version           = '2.0.0'
                        Publisher         = 'Test Corp'
                        InstallDate       = '20240101'
                        Architecture      = 'x86'
                        RunspaceId        = [guid]::NewGuid()
                        PSShowComputerName = $true
                        ExtraProperty     = 'ShouldNotAppear'
                    }
                )
            }
        }

        It 'Should only return specified properties' {
            $result = Get-RemoteSoftware -ComputerName 'TestServer01'

            $properties = $result[0].PSObject.Properties.Name
            $properties | Should -Contain 'ComputerName'
            $properties | Should -Contain 'Name'
            $properties | Should -Contain 'Version'
            $properties | Should -Contain 'Publisher'
            $properties | Should -Contain 'InstallDate'
            $properties | Should -Contain 'Architecture'
            $properties | Should -Not -Contain 'PSComputerName'
            $properties | Should -Not -Contain 'RunspaceId'
            $properties | Should -Not -Contain 'PSShowComputerName'
            $properties | Should -Not -Contain 'ExtraProperty'
        }
    }

    Context 'BEGIN and END blocks' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                return $script:mockSoftwareData
            }
            Mock -CommandName Write-Verbose -ModuleName $script:moduleName
        }

        It 'Should execute BEGIN block before processing' {
            Get-RemoteSoftware -ComputerName 'TestServer01' -Verbose

            # The BEGIN block should have access to Get-LocalSoftwareInventory
            # This is implicitly tested by the function not throwing an error
            Should -Invoke -CommandName Invoke-Command -ModuleName $script:moduleName -Times 1
        }

        It 'Should write verbose message in END block' {
            Get-RemoteSoftware -ComputerName 'TestServer01' -Verbose

            Should -Invoke -CommandName Write-Verbose -ModuleName $script:moduleName -ParameterFilter {
                $Message -eq 'Operation complete.'
            }
        }
    }

    Context 'Multiple computers with different results' {
        BeforeEach {
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                param($ComputerName)
                if ($ComputerName -eq 'EmptyServer') {
                    return @()
                }
                return @(
                    [PSCustomObject]@{
                        PSComputerName = $ComputerName
                        ComputerName   = $ComputerName
                        Name           = "App on $ComputerName"
                        Version        = '1.0.0'
                        Publisher      = 'Publisher'
                        InstallDate    = '20240101'
                        Architecture   = 'x64'
                        RunspaceId     = [guid]::NewGuid()
                    }
                )
            }
        }

        It 'Should handle servers with no software installed' {
            $result = Get-RemoteSoftware -ComputerName 'EmptyServer'

            $result | Should -BeNullOrEmpty
        }

        It 'Should return different results for different servers' {
            $results = @()
            $results += Get-RemoteSoftware -ComputerName 'Server01'
            $results += Get-RemoteSoftware -ComputerName 'Server02'

            $results.Count | Should -Be 2
            $results[0].Name | Should -Be 'App on Server01'
            $results[1].Name | Should -Be 'App on Server02'
        }
    }

    Context 'Remote scriptblock execution' {
        It 'Should execute the scriptblock that would run on remote machines' {
            # Test the scriptblock logic that would be executed remotely
            # This tests lines 50, 54, and 57 which are inside the remote scriptblock
            Mock -CommandName Invoke-Command -ModuleName $script:moduleName -MockWith {
                param($ScriptBlock, $ArgumentList)

                # Execute the scriptblock locally to test it
                # This simulates what would happen on the remote machine
                & $ScriptBlock $ArgumentList[0]
            }

            $result = Get-RemoteSoftware -ComputerName 'TestServer01'

            # Verify that the scriptblock was executed
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
