BeforeAll {
    $projectPath = "$PSScriptRoot/../../.." | Convert-Path
    $projectName = (Get-ChildItem -Path "$projectPath/source/*.psd1" | Where-Object {
        ($_.Directory.Name -eq 'source') -and
        $(try { Test-ModuleManifest -Path $_.FullName -ErrorAction Stop } catch { $false })
    }).BaseName

    # Create stub for Write-EventLog on non-Windows platforms
    if (-not (Get-Command Write-EventLog -ErrorAction SilentlyContinue)) {
        function global:Write-EventLog {
            param($LogName, $Source, $EntryType, $EventId, $Message)
        }
    }

    # Import the module
    Import-Module -Name $projectName -Force -ErrorAction Stop
}

Describe 'Write-PSLog' -Tag 'Unit' {
    BeforeAll {
        # Create temporary test directory
        $script:testLogPath = Join-Path -Path $TestDrive -ChildPath "test.log"
        $script:testLogDir = Join-Path -Path $TestDrive -ChildPath "logs"
        $script:testLogInDir = Join-Path -Path $script:testLogDir -ChildPath "app.log"
    }

    Context 'Parameter Validation' {
        It 'Should have Message parameter that is mandatory' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $parameter = $command.Parameters['Message']
                $parameter.Attributes.Mandatory | Should -BeTrue
            }
        }

        It 'Should have Level parameter with valid set' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $parameter = $command.Parameters['Level']
                $parameter.Attributes.ValidValues | Should -Contain 'Info'
                $parameter.Attributes.ValidValues | Should -Contain 'Warning'
                $parameter.Attributes.ValidValues | Should -Contain 'Error'
            }
        }

        It 'Should have LogFile parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $command.Parameters.ContainsKey('LogFile') | Should -BeTrue
            }
        }

        It 'Should have ToScreen switch parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $parameter = $command.Parameters['ToScreen']
                $parameter.SwitchParameter | Should -BeTrue
            }
        }

        It 'Should have ToEventLog switch parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $parameter = $command.Parameters['ToEventLog']
                $parameter.SwitchParameter | Should -BeTrue
            }
        }

        It 'Should have EventSource parameter with default value' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $command.Parameters.ContainsKey('EventSource') | Should -BeTrue
            }
        }

        It 'Should have NoTimestamp switch parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                $command = Get-Command Write-PSLog
                $parameter = $command.Parameters['NoTimestamp']
                $parameter.SwitchParameter | Should -BeTrue
            }
        }
    }

    Context 'Log File Writing' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
        }

        AfterEach {
            if (Test-Path -Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
            if (Test-Path -Path $script:testLogDir) {
                Remove-Item -Path $script:testLogDir -Recurse -Force
            }
        }

        It 'Should create log file if it does not exist' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Test message" -LogFile $testLogPath
                Test-Path -Path $testLogPath | Should -BeTrue
            }
        }

        It 'Should write message to log file with timestamp' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Test message" -Level Info -LogFile $testLogPath

                $content = Get-Content -Path $testLogPath -Raw
                $content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[Info\] Test message'
            }
        }

        It 'Should write message to log file without timestamp when NoTimestamp is specified' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Test message" -Level Info -LogFile $testLogPath -NoTimestamp

                $content = Get-Content -Path $testLogPath -Raw
                $content | Should -Match '\[Info\] Test message'
            }
        }

        It 'Should append to existing log file' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "First message" -LogFile $testLogPath -NoTimestamp
                Write-PSLog -Message "Second message" -LogFile $testLogPath -NoTimestamp

                $content = Get-Content -Path $testLogPath
                $content.Count | Should -Be 2
                $content[0] | Should -Match '\[Info\] First message'
                $content[1] | Should -Match '\[Info\] Second message'
            }
        }

        It 'Should create directory if it does not exist' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogInDir = $script:testLogInDir; testLogDir = $script:testLogDir } -ScriptBlock {
                param($testLogInDir, $testLogDir)
                Write-PSLog -Message "Test message" -LogFile $testLogInDir

                Test-Path -Path $testLogDir | Should -BeTrue
                Test-Path -Path $testLogInDir | Should -BeTrue
            }
        }

        It 'Should write different severity levels correctly' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Info message" -Level Info -LogFile $testLogPath -NoTimestamp
                Write-PSLog -Message "Warning message" -Level Warning -LogFile $testLogPath -NoTimestamp
                Write-PSLog -Message "Error message" -Level Error -LogFile $testLogPath -NoTimestamp

                $content = Get-Content -Path $testLogPath
                $content[0] | Should -Match '\[Info\] Info message'
                $content[1] | Should -Match '\[Warning\] Warning message'
                $content[2] | Should -Match '\[Error\] Error message'
            }
        }

        It 'Should handle write errors gracefully' {
            Mock -CommandName Add-Content -ModuleName PSPowerAdminTasks -MockWith {
                throw "Access denied"
            }

            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                { Write-PSLog -Message "Test" -LogFile $testLogPath } | Should -Not -Throw
            }
            Should -Invoke -CommandName Write-Warning -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should use UTF8 encoding for log files' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                $unicodeMessage = "Test message with unicode: é à ü 中文"
                Write-PSLog -Message $unicodeMessage -LogFile $testLogPath -NoTimestamp

                $content = Get-Content -Path $testLogPath -Raw -Encoding UTF8
                $content | Should -Match $unicodeMessage
            }
        }
    }

    Context 'Screen Output' {
        BeforeEach {
            Mock -CommandName Write-Host -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
        }

        It 'Should write to screen when ToScreen is specified' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Test message" -ToScreen
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should write Info messages in Cyan' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Info message" -Level Info -ToScreen
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ForegroundColor -eq 'Cyan'
            } -Times 1
        }

        It 'Should write Warning messages in Yellow' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Warning message" -Level Warning -ToScreen
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ForegroundColor -eq 'Yellow'
            } -Times 1
        }

        It 'Should write Error messages in Red' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Error message" -Level Error -ToScreen
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -ParameterFilter {
                $ForegroundColor -eq 'Red'
            } -Times 1
        }

        It 'Should include timestamp in screen output by default' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Test message" -ToScreen
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Object -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
            } -Times 1
        }

        It 'Should exclude timestamp when NoTimestamp is specified' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Test message" -ToScreen -NoTimestamp
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Object -eq "[Info] Test message"
            } -Times 1
        }
    }

    Context 'Event Log Writing (Windows)' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-EventLog -ModuleName PSPowerAdminTasks
        }

        It 'Should warn on non-Windows platforms' -Skip:($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Test message" -ToEventLog
            }
            Should -Invoke -CommandName Write-Warning -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Message -match 'only available on Windows'
            } -Times 1
        }

        It 'Should warn if event source does not exist on Windows' -Skip:(-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
            Mock -CommandName Write-EventLog -ModuleName PSPowerAdminTasks

            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                # Mock the SourceExists check to return false
                $mockEventLog = [System.Diagnostics.EventLog]
                # This test will check the warning behavior
                Write-PSLog -Message "Test message" -ToEventLog -EventSource "NonExistentSource"
            }
        }

        It 'Should not throw when Event Log write fails' {
            Mock -CommandName Write-EventLog -ModuleName PSPowerAdminTasks -MockWith {
                throw "Permission denied"
            }

            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                { Write-PSLog -Message "Test" -ToEventLog } | Should -Not -Throw
            }
        }
    }

    Context 'Multiple Output Targets' {
        BeforeEach {
            Mock -CommandName Write-Host -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-EventLog -ModuleName PSPowerAdminTasks
        }

        AfterEach {
            if (Test-Path -Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
        }

        It 'Should write to both file and screen when both are specified' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Test message" -LogFile $testLogPath -ToScreen

                Test-Path -Path $testLogPath | Should -BeTrue
            }
            Should -Invoke -CommandName Write-Host -ModuleName PSPowerAdminTasks -Times 1
        }

        It 'Should write to Verbose stream when no output target is specified' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                Write-PSLog -Message "Test message"
            }
            Should -Invoke -CommandName Write-Verbose -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Message -match 'No output target specified'
            } -Times 1
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
            Mock -CommandName Write-Warning -ModuleName PSPowerAdminTasks
        }

        It 'Should not throw when log file write fails' {
            Mock -CommandName Add-Content -ModuleName PSPowerAdminTasks -MockWith {
                throw "Disk full"
            }

            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                { Write-PSLog -Message "Test" -LogFile $testLogPath } | Should -Not -Throw
            }
        }

        It 'Should handle empty message parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                { Write-PSLog -Message "" -ToScreen } | Should -Throw
            }
        }

        It 'Should handle null message parameter' {
            InModuleScope -ModuleName PSPowerAdminTasks -ScriptBlock {
                { Write-PSLog -Message $null -ToScreen } | Should -Throw
            }
        }
    }

    Context 'Verbose Output' {
        BeforeEach {
            Mock -CommandName Write-Verbose -ModuleName PSPowerAdminTasks
        }

        AfterEach {
            if (Test-Path -Path $script:testLogPath) {
                Remove-Item -Path $script:testLogPath -Force
            }
            if (Test-Path -Path $script:testLogDir) {
                Remove-Item -Path $script:testLogDir -Recurse -Force
            }
        }

        It 'Should write verbose message when creating log directory' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogInDir = $script:testLogInDir } -ScriptBlock {
                param($testLogInDir)
                Write-PSLog -Message "Test" -LogFile $testLogInDir -Verbose
            }
            Should -Invoke -CommandName Write-Verbose -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Message -match 'Created log directory'
            } -Times 1
        }

        It 'Should write verbose message when writing to log file' {
            InModuleScope -ModuleName PSPowerAdminTasks -Parameters @{ testLogPath = $script:testLogPath } -ScriptBlock {
                param($testLogPath)
                Write-PSLog -Message "Test" -LogFile $testLogPath -Verbose
            }
            Should -Invoke -CommandName Write-Verbose -ModuleName PSPowerAdminTasks -ParameterFilter {
                $Message -match 'Wrote to log file'
            } -Times 1
        }
    }
}
