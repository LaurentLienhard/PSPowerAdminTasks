# Example 1: Generate GP Results report for a single server
Get-RemoteGPResult -ComputerName "SERVER01"

# Example 2: Generate and immediately display the report
Get-RemoteGPResult -ComputerName "SERVER01" -Show

# Example 3: Use specific credentials
$cred = Get-Credential
Get-RemoteGPResult -ComputerName "SERVER01" -Credential $cred -Show

# Example 4: Save report to a specific location
Get-RemoteGPResult -ComputerName "SERVER01" -OutputPath "C:\Reports\GPResult_Server01.html"

# Example 5: Generate report for a specific user
Get-RemoteGPResult -ComputerName "SERVER01" -Scope User -UserName "domain\jdoe" -Show

# Example 6: Generate report for computer scope only
Get-RemoteGPResult -ComputerName "SERVER01" -Scope Computer -Show

# Example 7: Process multiple servers via pipeline
"SERVER01", "SERVER02", "SERVER03" | Get-RemoteGPResult -Show

# Example 8: Process servers from CSV
Import-Csv "servers.csv" | Get-RemoteGPResult -OutputPath { "C:\Reports\GPResult_$($_.ComputerName).html" }
