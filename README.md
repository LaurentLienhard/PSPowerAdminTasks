# PSPowerAdminTasks

A PowerShell module containing system administration utilities for Windows environments.

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Functions](#functions)
  - [Administrative Task Functions](#administrative-task-functions)
  - [User and Security Functions](#user-and-security-functions)
  - [Network and Infrastructure Functions](#network-and-infrastructure-functions)
- [Classes](#classes)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [Versioning](#versioning)
- [CI/CD](#cicd)
- [License](#license)

## Description

PSPowerAdminTasks is a collection of PowerShell functions designed to simplify and automate common system administration tasks. The module is built using the [Sampler](https://github.com/gaelcolas/Sampler) framework, providing a standardized structure for building, testing, and publishing PowerShell modules.

This module provides 14+ functions and 3 custom PowerShell classes for managing:
- Remote computer administration (Group Policy, software, reboot logs)
- User and security management (account disabling, lockout investigation, permissions)
- Active Directory topology (sites, site links, latency analysis)
- Network infrastructure (DNS, DHCP, Windows updates)

## Requirements

- PowerShell 5.0 or higher
- Windows PowerShell Remoting enabled (for remote operations)

## Installation

### From PowerShell Gallery (when published)

```powershell
Install-Module -Name PSPowerAdminTasks -Scope CurrentUser
```

### From Source

1. Clone the repository:
   ```powershell
   git clone https://github.com/LaurentLienhard/PSPowerAdminTasks.git
   cd PSPowerAdminTasks
   ```

2. Bootstrap dependencies:
   ```powershell
   ./build.ps1 -ResolveDependency -Tasks noop
   ```

3. Build the module:
   ```powershell
   ./build.ps1 -Tasks build
   ```

4. Import the built module:
   ```powershell
   Import-Module ./output/module/PSPowerAdminTasks/<version>/PSPowerAdminTasks.psd1
   ```

## Functions

### Administrative Task Functions

#### Get-RemoteGPResult

Generates and retrieves a Group Policy results report from a remote computer.

**Features:**
- Execute `gpresult /h` on remote computer via PowerShell Remoting
- Automatically copy HTML report to local machine
- Support for Computer, User, or Both scopes
- Optional immediate display in browser with `-Show` switch
- Custom output path support
- Specific user account querying
- Pipeline support for multiple computers
- Automatic cleanup of remote temporary files

**Parameters:**
- `ComputerName` - Name or IP address of the remote computer (Mandatory)
- `Credential` - PSCredential object for authentication (Optional)
- `OutputPath` - Local path where the HTML report will be saved (Optional)
- `Scope` - Scope of the report: 'Computer', 'User', or 'Both' (Default: 'Both')
- `Show` - Opens the HTML report in the default browser after retrieval (Optional)
- `UserName` - For 'User' or 'Both' scope, specify the user account to query (Optional)

**Examples:**

```powershell
# Generate GP results report for a single server
Get-RemoteGPResult -ComputerName "SERVER01"

# Generate and immediately display the report
Get-RemoteGPResult -ComputerName "SERVER01" -Show

# Use specific credentials
Get-RemoteGPResult -ComputerName "SERVER01" -Credential (Get-Credential) -Show

# Save report to a specific location
Get-RemoteGPResult -ComputerName "SERVER01" -OutputPath "C:\Reports\GPResult_Server01.html"

# Generate report for a specific user
Get-RemoteGPResult -ComputerName "SERVER01" -Scope User -UserName "domain\jdoe" -Show

# Process multiple servers via pipeline
"SERVER01", "SERVER02", "SERVER03" | Get-RemoteGPResult -Show
```

#### Get-RemoteSoftware

Retrieves the list of installed software from remote servers via the Windows Registry.

**Features:**
- Uses PowerShell Remoting for fast and secure data retrieval
- Queries both 32-bit and 64-bit software installations
- Supports multiple remote servers simultaneously
- Compatible with Windows Server 2008 through 2022
- Accepts pipeline input for integration with Active Directory cmdlets

**Parameters:**
- `ComputerName` - One or more server names or IP addresses (Mandatory)
- `Credential` - PSCredential object for authentication (Optional)

**Examples:**

```powershell
# Get software from a single server
Get-RemoteSoftware -ComputerName "SRV-DB01"

# Query multiple servers with alternate credentials
Get-RemoteSoftware -ComputerName "SRV-WEB01", "SRV-WEB02" -Credential (Get-Credential)

# Export software inventory from all domain computers
Get-ADComputer -Filter * | Get-RemoteSoftware | Export-Csv "SoftwareInventory.csv" -NoTypeInformation

# Get software from all servers in Active Directory
Get-ADComputer -Filter {OperatingSystem -like "*Server*"} |
    Select-Object -ExpandProperty Name |
    Get-RemoteSoftware -Credential (Get-Credential)
```

#### Get-RemoteRebootLog

Retrieves reboot logs from remote servers with readable reason codes and timestamps.

**Features:**
- Queries System event log for reboot events (IDs: 1074, 6006, 6008, 1076)
- Human-readable shutdown reason mappings
- Support for time-based filtering
- Pipeline support for multiple servers
- Handles both clean shutdowns and unexpected reboots

**Parameters:**
- `ComputerName` - One or more server names or IP addresses (Mandatory, pipeline support)
- `Credential` - Credentials to connect to remote servers (Optional)
- `MaxEvents` - Maximum number of events to return (Default: 50, Range: 1-1000)
- `StartTime` - Start date for event filtering (Default: 30 days ago)

**Examples:**

```powershell
# Get reboot logs from a single server
Get-RemoteRebootLog -ComputerName "SERVER01"

# Get last 100 reboot events from multiple servers
Get-RemoteRebootLog -ComputerName "SERVER01", "SERVER02" -MaxEvents 100

# Get reboot logs for the last 7 days
Get-RemoteRebootLog -ComputerName "SERVER01" -StartTime (Get-Date).AddDays(-7)

# Get reboot logs with alternate credentials
Get-RemoteRebootLog -ComputerName "SERVER01" -Credential (Get-Credential)

# Pipeline from AD
Get-ADComputer -Filter {OperatingSystem -like "*Server*"} | Get-RemoteRebootLog
```

### User and Security Functions

#### Disable-CompromisedUser

Rapidly disables one or more compromised user accounts with flexible input methods.

**Features:**
- Supports three input methods: Direct list, file-based list, or organizational unit
- Optional log file generation in $env:Temp
- Check-only mode to verify disabled status
- Console output logging capability
- Supports alternate credentials

**Parameters:**
- `Identity` - One or more user accounts to disable (Parameter Set: ByUser)
- `FileName` - Path to file containing list of users (one per line) (Parameter Set: ByFileName)
- `OU` - One or more distinguished names of OUs (Parameter Set: ByOu)
- `Check` - Only check disabled status, don't modify (Optional Switch)
- `Credential` - User credentials for AD operations (Optional)
- `Log` - Generate log file in $env:Temp (Optional Switch)
- `Console` - Display log information in console (Requires `-Log`)

**Examples:**

```powershell
# Disable a single user
Disable-CompromisedUser -Identity "User1"

# Disable multiple users with logging
Disable-CompromisedUser -Identity "User1","User2","User3" -Log -Console

# Disable users from file
Disable-CompromisedUser -FileName "C:\temp\CompromisedUsers.txt" -Log

# Check status without modifying
Disable-CompromisedUser -Identity "User1" -Check

# Disable all users in an OU
Disable-CompromisedUser -OU "OU=TestUsers,DC=contoso,DC=com"

# Disable users from multiple OUs with logging
Disable-CompromisedUser -OU "OU=OU1,DC=contoso,DC=com","OU=OU2,DC=contoso,DC=com" -Log
```

#### Get-UserLockoutInformation

Retrieves complete lockout information for user accounts including timestamp, DC, and reason codes.

**Features:**
- Queries event ID 4740 (account locked out)
- Retrieves failure details from source computer
- Includes lockout reason with human-readable descriptions
- Supports both single user and all locked users queries
- Option to specify custom DC

**Parameters:**
- `Identity` - Specific user to check (Parameter Set: ByUser)
- `DC` - Domain controller to query (Default: PDC Emulator)
- `Credential` - Administrator credentials for DC access

**Examples:**

```powershell
# Get all locked user accounts
Get-UserLockoutInformation -Credential (Get-Credential)

# Get lockout info for specific user
Get-UserLockoutInformation -Identity "User1" -Credential (Get-Credential)

# Query specific domain controller
Get-UserLockoutInformation -Identity "User1" -DC "DC02.contoso.com"
```

#### Get-EffectiveADAccess

Retrieves effective permissions (ACL) for a user or group on an Active Directory object.

**Features:**
- Analyzes direct and inherited ACEs
- Includes group membership implications
- Returns detailed permission information
- Supports multiple identity formats

**Parameters:**
- `Identity` - Target AD object (DistinguishedName, GUID, or sAMAccountName)
- `Principal` - User or group to check permissions for
- `Server` - Specific AD server to query
- `Credential` - Administrator credentials

**Examples:**

```powershell
# Check permissions for a group on container
Get-EffectiveADAccess -Identity "CN=Users,DC=contoso,DC=com" -Principal "contoso\Domain Admins"

# Check user permissions on their own object
Get-EffectiveADAccess -Identity "CN=john.doe,CN=Users,DC=contoso,DC=com" -Principal "john.doe"

# Pipeline from Get-ADUser
Get-ADUser -Identity john.doe | Get-EffectiveADAccess -Principal "Domain Users"
```

#### Get-RemoteUserLogons

Retrieves logon events from remote servers with human-readable logon type filtering.

**Features:**
- Queries Security event log (ID 4624)
- Human-readable logon type filtering (Interactive, RDP, Network, Service, Batch, Unlock, Cached)
- Configurable history lookback in days
- Automatic filtering of system and machine accounts
- Pipeline support

**Parameters:**
- `ComputerName` - Target server(s) (Mandatory, pipeline support)
- `Days` - Days of history to query (Default: 1)
- `LogonType` - Filter by logon type (Optional, auto-complete available)
- `Credential` - Credentials for remote access

**Examples:**

```powershell
# Get logon events from last 24 hours
Get-RemoteUserLogons -ComputerName "SERVER01"

# Get RDP logons from last 7 days
Get-RemoteUserLogons -ComputerName "SERVER01" -Days 7 -LogonType RDP

# Get multiple logon types
Get-RemoteUserLogons -ComputerName "SERVER01" -LogonType Interactive, RDP

# Get logons from multiple servers
Get-RemoteUserLogons -ComputerName "SERVER01","SERVER02" -Days 7
```

### Network and Infrastructure Functions

#### Get-SiteInformation

Retrieves Active Directory Sites and Services information including subnets and inter-site links.

**Features:**
- Returns SITE class objects with complete topology information
- Queries all or specific sites with wildcard support
- Includes subnet and site link information
- Calculates total inter-site cost
- Returns detailed creation/modification timestamps

**Parameters:**
- `Name` - Site name(s) with wildcard support (Default: all sites)
- `Server` - Specific domain controller to query
- `Credential` - Authentication credentials

**Examples:**

```powershell
# Get all AD sites
Get-SiteInformation

# Get specific site
Get-SiteInformation -Name "Default-First-Site-Name"

# Get sites matching pattern
Get-SiteInformation -Name "Site-*"

# Export site info to CSV
Get-SiteInformation | Export-Csv -Path "C:\Audit\ADSites.csv" -NoTypeInformation

# Find sites without subnets
Get-SiteInformation | Where-Object { $_.Subnets.Count -eq 0 }
```

#### Get-LatencyMatrix

Generates an inter-DC latency heatmap report showing response times between domain controllers.

**Features:**
- Full mesh latency testing between all specified DCs
- Color-coded HTML report (green/yellow/red thresholds)
- Parallel execution for efficiency
- Supports optional credentials
- Auto-opens report in default browser

**Parameters:**
- `DCList` - Array of DC hostnames or IP addresses (Mandatory)
- `ReportPath` - Full path for HTML report output (Mandatory)
- `Credential` - Optional credentials for WinRM connections

**Examples:**

```powershell
# Generate latency matrix for domain controllers
$DCs = "DC01", "DC02", "DC03", "DC04"
Get-LatencyMatrix -DCList $DCs -ReportPath "C:\Reports\LatencyMatrix.html"

# With credentials
Get-LatencyMatrix -DCList $DCs -ReportPath "C:\Reports\LatencyMatrix.html" -Credential (Get-Credential)
```

#### Get-RemoteDnsServer

Retrieves DNS server configuration from remote computers.

**Features:**
- Queries DNS configuration via COMPUTER class
- Returns DNS servers and IPv4 address information
- Validates computer existence in Active Directory
- Supports credentials for remote access

**Parameters:**
- `ComputerName` - Target server(s) (Mandatory, pipeline support)
- `Credential` - Optional credentials for remote access

**Examples:**

```powershell
# Get DNS config from single server
Get-RemoteDnsServer -ComputerName "SERVER01"

# Get from multiple servers
Get-RemoteDnsServer -ComputerName "SERVER01","SERVER02"

# With alternate credentials
Get-RemoteDnsServer -ComputerName "SERVER01" -Credential (Get-Credential)
```

#### Set-RemoteDnsServer

Sets or replaces DNS server addresses on remote computers.

**Features:**
- Two modes: Set all DNS servers or replace specific address
- Uses COMPUTER class for management
- Validates connectivity before changes
- Returns detailed success/failure report

**Parameters:**
- `ComputerName` - Target server(s) (Mandatory, pipeline support)
- `ServerAddresses` - List of DNS IPs to set (Parameter Set: All)
- `OldAddress` - DNS IP to replace (Parameter Set: Replace)
- `NewAddress` - New DNS IP address (Parameter Set: Replace)
- `Credential` - Optional credentials

**Examples:**

```powershell
# Set all DNS servers
Set-RemoteDnsServer -ComputerName "SERVER01" -ServerAddresses "8.8.8.8","8.8.4.4"

# Replace single DNS entry
Set-RemoteDnsServer -ComputerName "SERVER01" -OldAddress "1.1.1.1" -NewAddress "8.8.8.8"

# Multiple servers
Set-RemoteDnsServer -ComputerName "SERVER01","SERVER02" -ServerAddresses "8.8.8.8","8.8.4.4"
```

#### Set-RemoteDnsDebugLog

Enables or disables DNS server debug logging on remote systems.

**Features:**
- Enables/disables debug packet logging
- Configurable log file path and max file size
- Uses CIM session for credential handling
- Supports WhatIf for safety
- Logging for Local Lookup, Remote Server, Recursive Lookup, and Zone Loading events

**Parameters:**
- `ComputerName` - Target DNS server (Mandatory, pipeline support)
- `LogFilePath` - Absolute path on remote server for log file (Mandatory for Enable)
- `MaxSize` - Maximum log file size in bytes (Default: 500MB)
- `Disable` - Switch to disable logging
- `Credential` - Optional credentials for remote access

**Examples:**

```powershell
# Enable DNS debug logging
Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -LogFilePath "C:\DnsLogs\debug.log"

# Set custom max size
Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -LogFilePath "C:\Logs\dns.log" -MaxSize 1GB

# Disable logging
Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -Disable

# With credentials
Set-RemoteDnsDebugLog -ComputerName "SRV-DNS01" -LogFilePath "C:\Logs\dns.log" -Credential (Get-Credential)
```

#### Get-RemoteDhcpScopes

Retrieves DHCP scope configuration, statistics, and options from remote DHCP servers.

**Features:**
- Lists all IPv4 scopes on remote DHCP server
- Retrieves scope statistics (Free/Used IPs)
- Extracts common DHCP options (Router, DNS, Domain)
- Identifies additional configured options
- Pipeline support for multiple servers

**Parameters:**
- `ComputerName` - DHCP server name (Mandatory, pipeline support)
- `Credential` - Optional credentials for remote connection

**Examples:**

```powershell
# Get DHCP scopes from server
Get-RemoteDhcpScopes -ComputerName "DHCP-SERVER01"

# With credentials
Get-RemoteDhcpScopes -ComputerName "DHCP-SERVER01" -Credential (Get-Credential)

# Export scope information
Get-RemoteDhcpScopes -ComputerName "DHCP-SERVER01" | Export-Csv "DhcpScopes.csv" -NoTypeInformation
```

#### Get-LastUpdate

Retrieves latest Windows Update information from computers with optional reporting options.

**Features:**
- Queries last hotfix installed via COMPUTER class
- Two modes: specific computers or all supported servers
- Optional Google Drive upload integration
- Optional email report delivery
- Automatic CSV export to temp directory

**Parameters:**
- `ComputerName` - Target computer(s) (Parameter Set: ByComputerName)
- `OnlySupported` - Query only supported Windows versions (Parameter Set: OnlySupported)
- `UploadToGDriveParams` - Hashtable for Google Drive upload options
- `SendByMail` - Send report via email
- `Credential` - Optional credentials

**Examples:**

```powershell
# Get last update from server
Get-LastUpdate -ComputerName "SERVER01"

# Get from all supported servers (2016/2019/2022)
Get-LastUpdate -OnlySupported

# With email report
Get-LastUpdate -ComputerName "SERVER01" -SendByMail

# Multiple servers
Get-LastUpdate -ComputerName "SERVER01","SERVER02","SERVER03"
```

## Classes

The module includes custom PowerShell classes for managing domain infrastructure:

### COMPUTER Class

Represents a domain-joined computer with properties and methods for system management.

**Properties:**
- `Name` - Computer name
- `Status` - Ping status (Ping OK, Ping Failed, Host Unknown)
- `IPv4Address` - IPv4 address from Active Directory
- `DnsServers` - Comma-separated DNS server list
- `Operatingsystem` - OS version from AD
- `SamAccountName` - Computer account SAM name
- `Created` - Computer account creation timestamp
- `LastLogontimestamp` - Last logon time
- `MemberOF` - WSUS group membership
- `HotfixID` - Latest installed hotfix ID
- `LastBootUptime` - Last system boot time
- `RebootNeeded` - YES/NO reboot requirement status

**Methods:**
- `GetAllInformation()` - Retrieves all computer information
- `TestIfComputerIsOnline()` - Tests connectivity
- `TestIfComputerExistInAd()` - Validates AD presence
- `GetDnsConfig()` - Retrieves DNS configuration
- `SetDnsServers()` - Sets all DNS servers
- `AddDnsServer()` - Adds a single DNS server
- `RemoveDnsServer()` - Removes a DNS server
- `ModifyDnsServer()` - Replaces a DNS server entry
- `GetComputerLastHotFix()` - Retrieves latest patch info
- `GetComputerLastBootUptime()` - Gets last boot time
- `TestIfRebootNeeded()` - Checks reboot requirement

**Examples:**

```powershell
# Create COMPUTER object
$computer = [COMPUTER]::new("SERVER01")

# Get all information
$computer.GetAllInformation()

# Retrieve DNS configuration
$computer.GetDnsConfig()

# Set DNS servers
$computer.SetDnsServers("8.8.8.8","8.8.4.4")

# With credentials
$cred = Get-Credential
$computer = [COMPUTER]::new("SERVER01", $cred)
```

### SITE Class

Represents an Active Directory site with properties for topology management.

**Properties:**
- `Name` - Site name
- `Description` - Site description
- `Location` - Geographic location
- `DistinguishedName` - LDAP distinguished name
- `Subnets` - List of associated subnet DNs
- `SiteLinks` - Collection of SITELINK objects
- `TotalInterSiteCost` - Sum of all site link costs
- `WhenCreated` - Creation timestamp
- `WhenChanged` - Last modification timestamp

**Methods:**
- `AddSubnet()` - Adds a subnet to the site
- `RemoveSubnet()` - Removes a subnet
- `AddSiteLink()` - Adds a site link
- `RemoveSiteLink()` - Removes a site link
- `UpdateTotalInterSiteCost()` - Recalculates total cost
- `GetSiteLinksSummary()` - Returns formatted site link summary
- `ToHashtable()` - Converts to hashtable representation

**Static Methods:**
- `FromADObject()` - Creates SITE instance from AD object

**Examples:**

```powershell
# Get sites via function
$sites = Get-SiteInformation

# Access site properties
foreach ($site in $sites) {
    Write-Host "Site: $($site.Name)"
    Write-Host "Subnets: $($site.Subnets.Count)"
    Write-Host "Total Cost: $($site.TotalInterSiteCost)"

    # Display site links summary
    $site.GetSiteLinksSummary()
}
```

### SITELINK Class

Represents an Active Directory inter-site link with replication properties.

**Properties:**
- `Name` - Site link name
- `Description` - Site link description
- `Cost` - Replication cost (default: 100)
- `ReplicationFrequency` - Frequency in minutes (default: 180)
- `ReplaceWithInterSiteTopology` - ISTG override flag
- `Sites` - List of site names
- `WhenCreated` - Creation timestamp
- `WhenChanged` - Last modification timestamp
- `Options` - Additional configuration options

**Methods:**
- `AddSite()` - Adds a site to the link
- `RemoveSite()` - Removes a site from the link
- `ToHashtable()` - Converts to hashtable representation

**Static Methods:**
- `FromADObject()` - Creates SITELINK instance from AD object

**Examples:**

```powershell
# Access site links through SITE object
$site = Get-SiteInformation -Name "Default-First-Site-Name" | Select-Object -First 1

foreach ($link in $site.SiteLinks) {
    Write-Host "Link: $($link.Name)"
    Write-Host "Cost: $($link.Cost)"
    Write-Host "Frequency: $($link.ReplicationFrequency) minutes"
    Write-Host "Sites: $($link.Sites -join ', ')"
}
```

## Development

This project uses the Sampler framework for building and testing.

### Common Tasks

```powershell
# Install build dependencies
./build.ps1 -ResolveDependency -Tasks noop

# Build the module
./build.ps1 -Tasks build

# Run all tests
./build.ps1 -Tasks test

# Build and package
./build.ps1 -Tasks pack
```

### Project Structure

```
PSPowerAdminTasks/
├── source/
│   ├── Public/         # Exported functions
│   ├── Private/        # Internal helper functions
│   ├── Classes/        # PowerShell classes
│   ├── en-US/          # Help documentation
│   └── PSPowerAdminTasks.psd1
├── tests/
│   ├── Unit/           # Unit tests
│   └── QA/             # Quality assurance tests
├── build.yaml          # Build configuration
└── build.ps1           # Build script
```

### Adding New Functions

1. Create your function in `source/Public/` (exported) or `source/Private/` (internal)
2. Use comment-based help with examples
3. Create corresponding Pester tests in `tests/Unit/`
4. Build and test: `./build.ps1 -Tasks build, test`

## Testing

The module uses Pester 5 for testing with an 85% code coverage requirement.

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run tests with specific tags
./build.ps1 -Tasks test -PesterTag 'Integration'
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Add or update tests for your changes
4. Ensure all tests pass (`./build.ps1 -Tasks test`)
5. Commit your changes with clear messages
6. Push to your fork and submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## Versioning

This project uses [GitVersion](https://gitversion.net/) for semantic versioning based on git history and commit messages.

**Commit message keywords:**
- `breaking change`, `breaking`, `major` → Major version bump
- `adds`, `feature`, `minor` → Minor version bump
- `fix`, `patch` → Patch version bump
- `+semver: none` or `+semver: skip` → No version bump

## CI/CD

The project uses Azure Pipelines for continuous integration and deployment:

- **Build Stage**: Packages module on Ubuntu
- **Test Stage**: Runs tests on Linux, Windows (PS 7), Windows (PS 5.1), and macOS
- **Deploy Stage**: Publishes to GitHub and PowerShell Gallery (main branch only)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Laurent LIENHARD

## Acknowledgments

- Built with the [Sampler](https://github.com/gaelcolas/Sampler) framework
- Thanks to all contributors who provide feedback, code, and suggestions
