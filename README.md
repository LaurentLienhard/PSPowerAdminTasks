# PSPowerAdminTasks

A PowerShell module containing system administration utilities for Windows environments.

## Description

PSPowerAdminTasks is a collection of PowerShell functions designed to simplify and automate common system administration tasks. The module is built using the [Sampler](https://github.com/gaelcolas/Sampler) framework, providing a standardized structure for building, testing, and publishing PowerShell modules.

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

### Get-RemoteGPResult

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

### Get-RemoteSoftware

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
