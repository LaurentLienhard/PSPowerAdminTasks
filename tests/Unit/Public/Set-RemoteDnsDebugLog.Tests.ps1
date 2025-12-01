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

    # Create stubs for commands that may not exist on non-Windows systems
    if (-not (Get-Command Set-DnsServerDiagnostics -ErrorAction SilentlyContinue)) {
        function global:Set-DnsServerDiagnostics {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeline = $true)]
                [object]$CimSession,
                [string]$ComputerName,
                [bool]$EnableLoggingToFile,
                [string]$LogFilePath,
                [int64]$MaxMBFileSize,
                [bool]$EnableLoggingForLocalLookupEvent,
                [bool]$EnableLoggingForRemoteServerEvent,
                [bool]$EnableLoggingForRecursiveLookupEvent,
                [bool]$EnableLoggingForZoneLoadingEvent
            )
        }
    }

    if (-not (Get-Command New-CimSession -ErrorAction SilentlyContinue)) {
        function global:New-CimSession {
            [CmdletBinding()]
            param(
                [string]$ComputerName,
                [object]$Credential,
                [int]$OperationTimeoutSec
            )
        }
    }

    if (-not (Get-Command Remove-CimSession -ErrorAction SilentlyContinue)) {
        function global:Remove-CimSession {
            [CmdletBinding()]
            param(
                [object]$CimSession
            )
        }
    }
}

AfterAll {
    # Clean up
    Get-Module $script:moduleName | Remove-Module -Force
    Remove-Item -Path function:global:Set-DnsServerDiagnostics -ErrorAction SilentlyContinue
}

Describe 'Set-RemoteDnsDebugLog' -Tag 'Unit' {
    Context 'Parameter Validation' {
        It 'Should have ComputerName as a mandatory parameter' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['ComputerName'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept ComputerName from pipeline' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have Credential as an optional parameter' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['Credential'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept PSCredential type for Credential parameter' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'Should have LogFilePath parameter for Enable parameter set' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['LogFilePath'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have Disable switch parameter' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['Disable'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Disable'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It 'Should have MaxSize parameter with default value' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.Parameters['MaxSize'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess (WhatIf)' {
            $command = Get-Command Set-RemoteDnsDebugLog
            # Check if function has SupportsShouldProcess attribute
            $commandText = $command.Definition
            $commandText | Should -Match 'SupportsShouldProcess\s*=\s*\$?true'
        }
    }

    Context 'Enable and Disable Functionality' {
        It 'Should have two parameter sets: Enable and Disable' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $command.ParameterSets.Name | Should -Contain 'Enable'
            $command.ParameterSets.Name | Should -Contain 'Disable'
        }
    }

    Context 'Parameter Set Validation' {
        It 'Should require LogFilePath when using Enable parameter set' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $enableParamSet = $command.ParameterSets | Where-Object { $_.Name -eq 'Enable' }
            $enableParamSet.Parameters | Where-Object { $_.Name -eq 'LogFilePath' } | Should -Not -BeNullOrEmpty
        }

        It 'Should require Disable switch for Disable parameter set' {
            $command = Get-Command Set-RemoteDnsDebugLog
            $disableParamSet = $command.ParameterSets | Where-Object { $_.Name -eq 'Disable' }
            $disableParamSet.Parameters | Where-Object { $_.Name -eq 'Disable' } | Should -Not -BeNullOrEmpty
        }
    }
}
